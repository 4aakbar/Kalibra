/// Pengingat lokal (jalur utama, tetap jalan offline). Setiap kali jadwal
/// berubah, semua notifikasi dijadwalkan ulang dari state, jadi tidak ada
/// pengingat "yatim" setelah edit atau hapus (NFR-06).
library;

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_state.dart';
import 'dates.dart';
import 'models.dart' hide Priority;
import 'occurrences.dart';

/// iOS membatasi 64 notifikasi terjadwal; sisakan ruang.
const _maxScheduled = 56;
const _horizonDays = 21;

class PlannedReminder {
  final DateTime at;
  final String title;
  final String body;
  final String? scheduleId;
  final bool isDeadline;
  const PlannedReminder(this.at, this.title, this.body, this.scheduleId, this.isDeadline);
}

/// Hitung pengingat yang perlu dijadwalkan (fungsi murni, bisa dites).
List<PlannedReminder> planReminders(List<Schedule> schedules, Preferences prefs, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final horizon = addDays(n, _horizonDays);
  final out = <PlannedReminder>[];
  final occ = occurrencesInRange(schedules.where((s) => !(s.isDeadline && s.done)).toList(), n, addDays(horizon, 8));
  for (final o in occ) {
    for (final minutes in o.schedule.reminders) {
      final at = o.start.subtract(Duration(minutes: minutes));
      if (!at.isAfter(n) || at.isAfter(horizon)) continue;
      final when = o.schedule.allDay
          ? formatRelativeDay(o.start, at)
          : '${formatRelativeDay(o.start, at)} ${formatTime(o.start)}';
      out.add(PlannedReminder(
        at,
        o.schedule.isDeadline ? 'Deadline: ${o.schedule.title}' : o.schedule.title,
        o.schedule.isDeadline
            ? 'Tenggat $when. Udah dikerjain?'
            : '$when${o.schedule.location != null ? ' · ${o.schedule.location}' : ''}',
        o.schedule.id,
        o.schedule.isDeadline,
      ));
    }
  }
  if (prefs.morningSummary) {
    final startMin = hhmmToMinutes(prefs.dayStart);
    for (var i = 0; i < 7; i++) {
      final day = addDays(startOfDay(n), i);
      final at = DateTime(day.year, day.month, day.day, startMin ~/ 60, startMin % 60);
      if (!at.isAfter(n)) continue;
      final items = occurrencesOnDay(schedules, day);
      final acara = items.where((o) => !o.schedule.isDeadline).length;
      final deadline = items.where((o) => o.schedule.isDeadline && !o.schedule.done).length;
      final parts = [if (acara > 0) '$acara acara', if (deadline > 0) '$deadline deadline'];
      if (parts.isEmpty) continue;
      out.add(PlannedReminder(at, 'Ringkasan hari ini', 'Hari ini: ${parts.join(', ')}. Semangat!', null, false));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.take(_maxScheduled).toList();
}

class Reminders {
  Reminders(this.app);
  final AppState app;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;

  /// Dipanggil saat notifikasi atau tombolnya ditekan; diisi oleh UI untuk navigasi.
  void Function(String? scheduleId)? onOpen;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory('deadline', actions: [
              DarwinNotificationAction.plain('done', 'Tandai selesai'),
              DarwinNotificationAction.plain('snooze', 'Tunda 1 jam'),
            ]),
            DarwinNotificationCategory('acara', actions: [
              DarwinNotificationAction.plain('ok', 'Oke'),
              DarwinNotificationAction.plain('snooze', 'Tunda 10 menit'),
            ]),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    _ready = true;
  }

  void _onResponse(NotificationResponse r) {
    final payload = r.payload;
    final id = payload == null || payload.isEmpty ? null : payload;
    switch (r.actionId) {
      case 'done':
        if (id != null && app.byId(id)?.done == false) app.toggleDone(id);
      case 'snooze':
        // Tunda = ingatkan lagi nanti; jadwalnya sendiri tidak dipindah.
        final isDeadline = id != null && app.byId(id)?.isDeadline == true;
        final at = DateTime.now().add(Duration(minutes: isDeadline ? 60 : 10));
        _schedule(r.id ?? 0, PlannedReminder(at, 'Pengingat', app.byId(id ?? '')?.title ?? 'Jadwal', id, isDeadline));
      case 'ok':
        break;
      default:
        onOpen?.call(id);
    }
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    bool? ok;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      ok = await android?.requestNotificationsPermission();
      // Android 12+: izin alarm tepat waktu supaya pengingat nggak telat.
      await android?.requestExactAlarmsPermission();
    } else {
      ok = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    return ok ?? false;
  }

  NotificationDetails _details(bool isDeadline) => NotificationDetails(
        android: AndroidNotificationDetails(
          'pengingat',
          'Pengingat jadwal',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF3B2BD0),
          actions: isDeadline
              ? const [AndroidNotificationAction('done', 'Tandai selesai'), AndroidNotificationAction('snooze', 'Tunda 1 jam')]
              : const [AndroidNotificationAction('ok', 'Oke'), AndroidNotificationAction('snooze', 'Tunda 10 menit')],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: isDeadline ? 'deadline' : 'acara'),
      );

  Future<void> _schedule(int id, PlannedReminder p) async {
    await _plugin.zonedSchedule(
      id: id,
      title: p.title,
      body: p.body,
      scheduledDate: tz.TZDateTime.from(p.at, tz.local),
      notificationDetails: _details(p.isDeadline),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: p.scheduleId ?? '',
    );
  }

  Future<void> sync() async {
    if (!supported || !app.prefs.notificationsEnabled) return;
    await init();
    await _plugin.cancelAll();
    var id = 1;
    for (final p in planReminders(app.schedules, app.prefs)) {
      await _schedule(id++, p);
    }
  }

  /// Jadwalkan ulang dengan jeda supaya edit beruntun tidak memicu banyak sinkron.
  void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => sync().catchError((Object e) => debugPrint('$e')));
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
  }
}
