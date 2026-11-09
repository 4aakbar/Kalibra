/// State aplikasi (local-first). Jadwal, chat, dan preferensi disimpan di
/// perangkat lewat SharedPreferences, jadi Kalender, Deadline, dan Form tetap
/// jalan offline. Sinkron ke server menyusul setelah backend dipilih.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parser/parser.dart';
import 'dates.dart';
import 'models.dart';

String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

// ---------------------------------------------------------------------------
// Chat

enum DraftStatus { pending, saved, cancelled }

class DraftItem {
  Draft draft;
  DraftStatus status;
  String? scheduleId;
  DraftItem(this.draft, {this.status = DraftStatus.pending, this.scheduleId});

  Map<String, dynamic> toJson() => {'draft': draft.toJson(), 'status': status.name, 'scheduleId': scheduleId};
  factory DraftItem.fromJson(Map<String, dynamic> j) => DraftItem(
        Draft.fromJson(Map<String, dynamic>.from(j['draft'] as Map)),
        status: DraftStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => DraftStatus.pending),
        scheduleId: j['scheduleId'] as String?,
      );
}

enum ChatRole { user, bot, drafts }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final List<String> chips;

  /// Teks asli untuk tombol "Isi manual" saat input gagal dipahami (FR-10).
  final String? manualFallback;
  final List<DraftItem> items;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    this.text = '',
    this.chips = const [],
    this.manualFallback,
    this.items = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'chips': chips,
        'manualFallback': manualFallback,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        role: ChatRole.values.firstWhere((r) => r.name == j['role']),
        text: j['text'] as String? ?? '',
        chips: List<String>.from(j['chips'] as List? ?? const []),
        manualFallback: j['manualFallback'] as String?,
        items: (j['items'] as List? ?? const []).map((i) => DraftItem.fromJson(Map<String, dynamic>.from(i as Map))).toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}

/// Input untuk membuat jadwal baru.
class ScheduleInput {
  ScheduleKind kind;
  String title;
  DateTime start;
  DateTime? end;
  bool allDay;
  CategoryId category;
  Priority priority;
  Recurrence? recurrence;
  List<int> reminders;
  String? location;
  String? notes;
  String? link;
  String source;

  ScheduleInput({
    required this.kind,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    required this.category,
    this.priority = Priority.sedang,
    this.recurrence,
    this.reminders = const [],
    this.location,
    this.notes,
    this.link,
    this.source = 'manual',
  });
}

ScheduleInput? draftToInput(Draft d, Preferences prefs) {
  final t = draftTimes(d);
  if (t == null || d.title.isEmpty) return null;
  return ScheduleInput(
    kind: d.kind,
    title: d.title,
    start: t.start,
    end: t.end,
    allDay: d.allDay,
    category: d.category,
    priority: d.priority,
    recurrence: d.recurrence,
    reminders: [d.kind == ScheduleKind.deadline ? prefs.deadlineReminder : prefs.eventReminder],
    location: d.location,
    source: 'chat',
  );
}

final _greeting = RegExp(r'^(halo|hai|hi|hello|hey|pagi|siang|sore|malam|assalamualaikum|p)\b[\s!.]*$', caseSensitive: false);
final _thanks = RegExp(r'^(makasih|makasi|thanks|thank you|thx|terima kasih|mksh|oke+|ok|sip+|mantap)\b', caseSensitive: false);

// ---------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  static const _key = 'kalibra-v1';

  bool loaded = false;
  bool onboarded = false;

  /// Tur fitur sudah dilihat (atau dilewati).
  bool tourDone = false;
  Preferences prefs = const Preferences();
  List<Schedule> schedules = [];
  List<ChatMessage> chat = [];

  /// Draf yang sedang menunggu jawaban klarifikasi.
  ({String messageId, int index})? awaiting;
  bool typing = false;

  /// Dipanggil setiap jadwal atau preferensi berubah (menjadwalkan ulang pengingat).
  void Function()? onSchedulesChanged;

  SharedPreferences? _store;
  Timer? _saveTimer;

  Future<void> load() async {
    _store = await SharedPreferences.getInstance();
    final raw = _store!.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        onboarded = j['onboarded'] as bool? ?? false;
        tourDone = j['tourDone'] as bool? ?? onboarded;
        prefs = Preferences.fromJson(Map<String, dynamic>.from(j['prefs'] as Map? ?? {}));
        schedules = (j['schedules'] as List? ?? []).map((s) => Schedule.fromJson(Map<String, dynamic>.from(s as Map))).toList();
        chat = (j['chat'] as List? ?? []).map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map))).toList();
      } catch (e) {
        debugPrint('Gagal membaca data lokal: $e');
      }
    }
    loaded = true;
    notifyListeners();
  }

  void _changed({bool schedulesChanged = false}) {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _save);
    if (schedulesChanged) onSchedulesChanged?.call();
  }

  Future<void> _save() async {
    await _store?.setString(
      _key,
      jsonEncode({
        'onboarded': onboarded,
        'tourDone': tourDone,
        'prefs': prefs.toJson(),
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'chat': chat.map((m) => m.toJson()).toList(),
      }),
    );
  }

  // ---- Preferensi & onboarding -------------------------------------------

  void setPrefs(Preferences Function(Preferences p) update) {
    prefs = update(prefs);
    _changed(schedulesChanged: true);
  }

  void completeOnboarding() {
    onboarded = true;
    _changed();
  }

  void setTourDone(bool done) {
    tourDone = done;
    _changed();
  }

  /// Keluar / hapus akun: hapus semua data lokal.
  Future<void> resetAll() async {
    onboarded = false;
    tourDone = false;
    prefs = const Preferences();
    schedules = [];
    chat = [];
    awaiting = null;
    await _store?.remove(_key);
    notifyListeners();
    onSchedulesChanged?.call();
  }

  // ---- Jadwal ------------------------------------------------------------

  Schedule? byId(String id) {
    for (final s in schedules) {
      if (s.id == id) return s;
    }
    return null;
  }

  Schedule addSchedule(ScheduleInput i) {
    final now = DateTime.now();
    final s = Schedule(
      id: newId(),
      kind: i.kind,
      title: i.title,
      start: i.start,
      end: i.end,
      allDay: i.allDay,
      category: i.category,
      priority: i.priority,
      recurrence: i.recurrence,
      reminders: i.reminders,
      location: i.location,
      notes: i.notes,
      link: i.link,
      source: i.source,
      createdAt: now,
      updatedAt: now,
    );
    schedules = [...schedules, s];
    _changed(schedulesChanged: true);
    return s;
  }

  void replaceSchedule(Schedule s) {
    schedules = [for (final x in schedules) x.id == s.id ? s : x];
    _changed(schedulesChanged: true);
  }

  void updateFromInput(String id, ScheduleInput i) {
    final s = byId(id);
    if (s == null) return;
    replaceSchedule(s.copyWith(
      kind: i.kind,
      title: i.title,
      start: i.start,
      end: () => i.end,
      allDay: i.allDay,
      category: i.category,
      priority: i.priority,
      recurrence: () => i.recurrence,
      reminders: i.reminders,
      location: () => i.location,
      notes: () => i.notes,
      link: () => i.link,
    ));
  }

  Schedule? deleteSchedule(String id) {
    final s = byId(id);
    schedules = schedules.where((x) => x.id != id).toList();
    _changed(schedulesChanged: true);
    return s;
  }

  void restoreSchedule(Schedule s) {
    schedules = [...schedules.where((x) => x.id != s.id), s];
    _changed(schedulesChanged: true);
  }

  void toggleDone(String id) {
    final s = byId(id);
    if (s == null) return;
    replaceSchedule(s.copyWith(done: !s.done, doneAt: () => s.done ? null : DateTime.now()));
  }

  /// Tunda deadline (geser tenggat).
  void postpone(String id, Duration by) {
    final s = byId(id);
    if (s == null) return;
    final base = s.start.isAfter(DateTime.now()) ? s.start : DateTime.now();
    final start = base.add(by);
    replaceSchedule(s.copyWith(start: start, end: () => s.end == null ? null : start.add(s.end!.difference(s.start))));
  }

  /// "Hanya kejadian ini": lewati satu kejadian dari jadwal berulang.
  void skipOccurrence(String id, String key) {
    final s = byId(id);
    if (s == null) return;
    replaceSchedule(s.copyWith(exdates: {...s.exdates, key}.toList()));
  }

  /// "Kejadian ini dan berikutnya": akhiri pengulangan sebelum tanggal ini.
  void endRecurrenceBefore(String id, String key) {
    final s = byId(id);
    if (s == null || s.recurrence == null) return;
    final day = fromDateKey(key);
    if (!day.isAfter(startOfDay(s.start))) {
      deleteSchedule(id);
      return;
    }
    replaceSchedule(s.copyWith(recurrence: () => Recurrence(s.recurrence!.freq, until: dateKey(addDays(day, -1)))));
  }

  // ---- Chat (FR-06 s/d FR-10) --------------------------------------------

  ChatMessage _bot(String text, {List<String> chips = const [], String? manualFallback}) =>
      ChatMessage(id: newId(), role: ChatRole.bot, text: text, chips: chips, manualFallback: manualFallback);

  void pushChat(ChatMessage m) {
    chat = [...chat, m];
    _changed();
  }

  void clearChat() {
    chat = [];
    awaiting = null;
    _changed();
  }

  ChatMessage? _message(String id) {
    for (final m in chat) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _askNext(String messageId, int index, Draft d) {
    final q = clarificationQuestion(d);
    if (q == null) {
      awaiting = null;
      return;
    }
    awaiting = (messageId: messageId, index: index);
    pushChat(_bot(q.text, chips: q.chips));
  }

  void _askFirstMissing(ChatMessage m) {
    final idx = m.items.indexWhere((it) => it.status == DraftStatus.pending && it.draft.missing.isNotEmpty);
    if (idx >= 0) {
      _askNext(m.id, idx, m.items[idx].draft);
    } else {
      awaiting = null;
    }
  }

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    pushChat(ChatMessage(id: newId(), role: ChatRole.user, text: trimmed));
    if (RegExp(r'^batal$', caseSensitive: false).hasMatch(trimmed) && awaiting != null) {
      final a = awaiting!;
      _message(a.messageId)?.items[a.index].status = DraftStatus.cancelled;
      awaiting = null;
      pushChat(_bot('Oke, drafnya aku batalin.'));
      return;
    }
    typing = true;
    notifyListeners();
    // Jeda singkat supaya terasa seperti percakapan (target respons < 3 detik).
    Timer(const Duration(milliseconds: 450), () {
      try {
        _respond(trimmed, DateTime.now());
      } finally {
        typing = false;
        notifyListeners();
      }
    });
  }

  void _respond(String text, DateTime now) {
    // 1. Sedang menunggu jawaban klarifikasi
    final a = awaiting;
    if (a != null) {
      final msg = _message(a.messageId);
      if (msg != null && a.index < msg.items.length) {
        final updated = applyClarification(msg.items[a.index].draft, text, now);
        if (updated != null) {
          msg.items[a.index].draft = updated;
          if (updated.missing.isNotEmpty) {
            _askNext(msg.id, a.index, updated);
          } else {
            final rest = msg.items.indexWhere((it) =>
                it != msg.items[a.index] && it.status == DraftStatus.pending && it.draft.missing.isNotEmpty);
            if (rest >= 0) {
              _askNext(msg.id, rest, msg.items[rest].draft);
            } else {
              awaiting = null;
              pushChat(_bot('Sip, udah lengkap. Cek kartunya di atas, lalu tekan Simpan.'));
            }
          }
          return;
        }
      }
      if (parseMessage(text, now).failed) {
        pushChat(_bot('Maaf, aku belum nangkep. Coba tulis jam atau tanggalnya, misal "jam 4 sore" atau "Kamis".',
            chips: const ['Hari ini', 'Besok', 'Batal']));
        return;
      }
      awaiting = null;
    }

    // 2. Basa-basi
    if (_greeting.hasMatch(text)) {
      pushChat(_bot('Halo${prefs.nickname.isEmpty ? '' : ' ${prefs.nickname}'}! Mau nyatet apa hari ini?',
          chips: const ['Kuis besok jam 10', 'Deadline TK Jumat 23.59']));
      return;
    }
    if (_thanks.hasMatch(text)) {
      pushChat(_bot('Sama-sama! Kabarin aja kalau ada jadwal baru.'));
      return;
    }

    // 3. Jadwal baru
    final result = parseMessage(text, now);
    if (result.failed) {
      pushChat(_bot('Maaf, aku belum nangkep. Bisa tulis kegiatan, tanggal, dan jamnya? Misal: "Rapat BEM Jumat jam 4 sore".',
          manualFallback: text));
      return;
    }
    final m = ChatMessage(id: newId(), role: ChatRole.drafts, items: result.drafts.map(DraftItem.new).toList());
    pushChat(m);
    if (m.items.any((it) => it.draft.missing.isNotEmpty)) {
      _askFirstMissing(m);
    } else {
      pushChat(_bot(m.items.length > 1
          ? 'Aku bikin ${m.items.length} draf. Cek dulu, baru simpan ya.'
          : 'Ini drafnya. Cek dulu, baru simpan ya.'));
    }
  }

  /// Simpan draf jadi jadwal. Tidak ada yang tersimpan tanpa user menekan Simpan.
  String? saveDraft(String messageId, int index) {
    final m = _message(messageId);
    if (m == null || index >= m.items.length) return null;
    final item = m.items[index];
    if (item.status != DraftStatus.pending) return null;
    final input = draftToInput(item.draft, prefs);
    if (input == null) return null;
    final s = addSchedule(input);
    item
      ..status = DraftStatus.saved
      ..scheduleId = s.id;
    if (awaiting?.messageId == messageId && awaiting?.index == index) awaiting = null;
    _changed();
    return s.id;
  }

  void markDraftSaved(String messageId, int index, String scheduleId) {
    final m = _message(messageId);
    if (m == null || index >= m.items.length) return;
    m.items[index]
      ..status = DraftStatus.saved
      ..scheduleId = scheduleId;
    if (awaiting?.messageId == messageId && awaiting?.index == index) awaiting = null;
    _changed();
  }

  void cancelDraft(String messageId, int index) {
    final m = _message(messageId);
    if (m == null) return;
    m.items[index].status = DraftStatus.cancelled;
    if (awaiting?.messageId == messageId && awaiting?.index == index) {
      awaiting = null;
      _askFirstMissing(m);
    }
    _changed();
  }

  void updateDraft(String messageId, int index, void Function(Draft d) edit, {DraftField? confirmed}) {
    final m = _message(messageId);
    if (m == null) return;
    final d = m.items[index].draft;
    edit(d);
    if (confirmed != null) d.uncertain.remove(confirmed);
    _changed();
  }
}
