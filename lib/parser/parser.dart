/// Parser jadwal Bahasa Indonesia sehari-hari (berbasis aturan, jalan offline).
///
/// Implementasi lokal dari ekstraksi jadwal (FR-06 s/d FR-10). Nanti bisa
/// dilengkapi model AI di server, tapi aturannya tetap: hasilnya selalu draf
/// yang harus dikonfirmasi user, dan field wajib yang kosong ditanyakan balik.
library;

import '../core/dates.dart';
import '../core/models.dart';

class ClockTime {
  final int h;
  final int m;
  const ClockTime(this.h, this.m);
  @override
  bool operator ==(Object other) => other is ClockTime && other.h == h && other.m == m;
  @override
  int get hashCode => Object.hash(h, m);
  @override
  String toString() => 'ClockTime($h:$m)';
}

enum DraftField { judul, tanggal, jam, kategori }

class Draft {
  ScheduleKind kind;
  String title;

  /// Tanggal (jam 00.00).
  DateTime? date;
  ClockTime? time;
  ClockTime? endTime;
  bool allDay;
  CategoryId category;
  Priority priority;
  Recurrence? recurrence;
  String? location;

  /// Selisih jam zona yang disebut user terhadap zona perangkat (mis. user tulis WITA).
  int tzShiftHours;

  /// Field wajib yang belum ada, ditanyakan satu per satu.
  List<DraftField> missing;

  /// Field hasil tebakan (ditandai di kartu draf).
  List<DraftField> uncertain;
  String raw;

  Draft({
    required this.kind,
    required this.title,
    this.date,
    this.time,
    this.endTime,
    this.allDay = false,
    required this.category,
    this.priority = Priority.sedang,
    this.recurrence,
    this.location,
    this.tzShiftHours = 0,
    List<DraftField>? missing,
    List<DraftField>? uncertain,
    this.raw = '',
  })  : missing = missing ?? [],
        uncertain = uncertain ?? [];

  Draft copy() => Draft(
        kind: kind,
        title: title,
        date: date,
        time: time,
        endTime: endTime,
        allDay: allDay,
        category: category,
        priority: priority,
        recurrence: recurrence,
        location: location,
        tzShiftHours: tzShiftHours,
        missing: [...missing],
        uncertain: [...uncertain],
        raw: raw,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'title': title,
        'date': date == null ? null : dateKey(date!),
        'time': time == null ? null : [time!.h, time!.m],
        'endTime': endTime == null ? null : [endTime!.h, endTime!.m],
        'allDay': allDay,
        'category': category.name,
        'priority': priority.name,
        'recurrence': recurrence?.toJson(),
        'location': location,
        'tzShiftHours': tzShiftHours,
        'missing': missing.map((f) => f.name).toList(),
        'uncertain': uncertain.map((f) => f.name).toList(),
        'raw': raw,
      };

  factory Draft.fromJson(Map<String, dynamic> j) {
    ClockTime? clock(Object? v) => v == null ? null : ClockTime((v as List)[0] as int, v[1] as int);
    DraftField field(Object? n) => DraftField.values.firstWhere((f) => f.name == n);
    return Draft(
      kind: ScheduleKind.values.firstWhere((k) => k.name == j['kind']),
      title: j['title'] as String? ?? '',
      date: j['date'] == null ? null : fromDateKey(j['date'] as String),
      time: clock(j['time']),
      endTime: clock(j['endTime']),
      allDay: j['allDay'] as bool? ?? false,
      category: CategoryId.values.firstWhere((c) => c.name == j['category']),
      priority: Priority.values.firstWhere((p) => p.name == j['priority']),
      recurrence: j['recurrence'] == null ? null : Recurrence.fromJson(Map<String, dynamic>.from(j['recurrence'] as Map)),
      location: j['location'] as String?,
      tzShiftHours: j['tzShiftHours'] as int? ?? 0,
      missing: (j['missing'] as List? ?? []).map(field).toList(),
      uncertain: (j['uncertain'] as List? ?? []).map(field).toList(),
      raw: j['raw'] as String? ?? '',
    );
  }
}

class ParseResult {
  final List<Draft> drafts;

  /// true kalau tidak ada yang bisa dipahami sama sekali (FR-10).
  final bool failed;
  const ParseResult(this.drafts, this.failed);
}

// ---------------------------------------------------------------------------
// Kamus

/// Nilai mengikuti DateTime.weekday (Senin = 1 ... Minggu = 7).
const _weekdays = {
  'senin': 1, 'selasa': 2, 'rabu': 3, 'kamis': 4, 'jumat': 5, "jum'at": 5, 'jumaat': 5, 'sabtu': 6, 'minggu': 7, 'ahad': 7,
};
const _weekdayRe = "(senin|selasa|rabu|kamis|jum'?at|jumaat|sabtu|minggu|ahad)";

int? _weekdayOf(String token) => _weekdays[token] ?? _weekdays[token.replaceAll("'", '')];

const _monthRe =
    '(jan(?:uari)?|feb(?:ruari)?|mar(?:et)?|apr(?:il)?|mei|jun(?:i)?|jul(?:i)?|agu(?:stus)?|agt|ags|sep(?:t(?:ember)?)?|okt(?:ober)?|nov(?:ember)?|des(?:ember)?)';

int _monthIndex(String token) {
  const prefixes = ['jan', 'feb', 'mar', 'apr', 'mei', 'jun', 'jul', 'ag', 'sep', 'okt', 'nov', 'des'];
  for (var i = 0; i < prefixes.length; i++) {
    if (token.startsWith(prefixes[i])) return i + 1;
  }
  return 1;
}

final _deadlineWords = RegExp(r'\b(deadline|dl|tenggat|due|submit|dikumpul(?:in|kan)?|kumpul(?:in)?|pengumpulan|ngumpulin)\b');
final _taskWords = RegExp(r'\b(tugas|laprak|tk|pr|makalah|esai|essay|paper|laporan|resume|review|jurnal|assignment)\b');

final _categoryWords = <(CategoryId, RegExp)>[
  (CategoryId.tugas, _taskWords),
  (CategoryId.organisasi, RegExp(r'\b(rapat|rapim|bem|hima|himpunan|kepanitiaan|panitia|ukm|organisasi|osjur|pensi|divisi|sie|oprec|proker|evaluasi)\b')),
  (CategoryId.magang, RegExp(r'\b(magang|intern|internship|kantor|kerja|shift|interview|wawancara|onboarding)\b')),
  (
    CategoryId.kuliah,
    RegExp(r'\b(kuis|quiz|kuliah|kelas|uts|uas|ujian|praktikum|prak|asistensi|responsi|lab|dosen|matkul|alin|basdat|sda|ddp|ddak|pbp|fisdas|kalkulus|kalkul|matdis|sosi|ppd|jarkom|statprob|psd|sisop|os|mpkt|rpl|ppl|tba|dap)\b')
  ),
  (CategoryId.pribadi, RegExp(r'\b(futsal|gym|olahraga|lari|renang|nonton|makan|dokter|ulang tahun|ultah|nikahan|kondangan|pulang|mudik|belanja|date|nongkrong|main|keluarga)\b')),
];

/// Kapitalisasi singkatan kampus yang umum.
const _casing = {
  'alin': 'Alin', 'basdat': 'BasDat', 'sda': 'SDA', 'ddp': 'DDP', 'ddak': 'DDAK', 'pbp': 'PBP', 'fisdas': 'Fisdas',
  'matdis': 'MatDis', 'sosi': 'SOSI', 'ppd': 'PPD', 'jarkom': 'Jarkom', 'statprob': 'StatProb', 'psd': 'PSD',
  'sisop': 'SisOp', 'os': 'OS', 'mpkt': 'MPKT', 'rpl': 'RPL', 'ppl': 'PPL', 'tba': 'TBA', 'dap': 'DAP', 'tk': 'TK',
  'pr': 'PR', 'uts': 'UTS', 'uas': 'UAS', 'bem': 'BEM', 'hima': 'HIMA', 'ukm': 'UKM', 'laprak': 'Laprak',
  'kalkulus': 'Kalkulus', 'ui': 'UI', 'fasilkom': 'Fasilkom', 'scele': 'SCeLe', 'siak': 'SIAK', 'zoom': 'Zoom',
  'gmeet': 'GMeet', 'ai': 'AI', 'ml': 'ML', 'it': 'IT', 'ppt': 'PPT', 'pusgiwa': 'Pusgiwa', 'mipa': 'MIPA',
};

const _filler = {
  'ada', 'aku', 'gw', 'gue', 'gua', 'saya', 'ku', 'tolong', 'dong', 'ya', 'yaa', 'yah', 'nih', 'sih', 'pada', 'tanggal',
  'tgl', 'jam', 'pukul', 'pkl', 'nanti', 'ntar', 'hari', 'mulai', 'dari', 'ingetin', 'ingatkan', 'ingatin', 'jangan',
  'lupa', 'catat', 'catet', 'masukin', 'tambahin', 'buat', 'bikin', 'ke', 'kalender', 'jadwal', 'ini', 'itu', 'yang',
  'aja', 'deh', 'kok', 'tuh', 'sampai', 'sampe', 'hingga', 'tiap', 'setiap', 'depan', 'sekali', 'ok', 'oke', 'eh',
};

// ---------------------------------------------------------------------------
// Waktu

enum _Period { pagi, siang, sore, malam }

_Period? _normPeriod(String? p) {
  if (p == null) return null;
  if (p.startsWith('pagi')) return _Period.pagi;
  if (p.startsWith('siang')) return _Period.siang;
  if (p.startsWith('sore')) return _Period.sore;
  if (p.startsWith('mal')) return _Period.malam;
  return null;
}

/// Ubah jam 12-an jadi 24 jam sesuai keterangan waktu. uncertain=true kalau tebakan.
(int, bool) _applyPeriod(int h, _Period? period) {
  switch (period) {
    case _Period.pagi:
      return (h == 12 ? 0 : h, false);
    case _Period.siang:
      return (h >= 1 && h <= 5 ? h + 12 : h, false);
    case _Period.sore:
      return (h < 12 ? h + 12 : h, false);
    case _Period.malam:
      if (h == 12) return (0, false);
      return (h >= 6 && h < 12 ? h + 12 : (h <= 4 ? h : h + 12), false);
    case null:
      // Tanpa keterangan: "jam 3" hampir pasti 15.00 buat mahasiswa, tapi tandai untuk dicek.
      if (h >= 1 && h <= 6) return (h + 12, true);
      return (h, false);
  }
}

class TimeExtraction {
  final ClockTime? time;
  final ClockTime? endTime;
  final bool uncertain;
  final String text;
  const TimeExtraction({this.time, this.endTime, this.uncertain = false, required this.text});
}

const _periodRe = r'(?:\s*(pagi|siang|sore|malam|malem))?';

bool _valid(int h, int m) => h >= 0 && h <= 24 && m >= 0 && m < 60;
ClockTime _clamp24(int h, int m) => h == 24 ? const ClockTime(23, 59) : ClockTime(h, m);

TimeExtraction extractTime(String input) {
  var text = ' $input ';

  // Rentang: "jam 10-12", "10.00-11.40", "jam 1 sampai 3 sore"
  final range = RegExp(
    '(?:\\b(jam|pukul|pkl)\\s*)?\\b(\\d{1,2})(?:[.:](\\d{2}))?$_periodRe\\s*(?:-|–|sampai|sampe|s/d|hingga)\\s*(?:jam\\s*)?(\\d{1,2})(?:[.:](\\d{2}))?$_periodRe\\b',
  ).firstMatch(text);
  if (range != null && (range.group(1) != null || (range.group(3) != null && range.group(6) != null))) {
    final p2 = _normPeriod(range.group(7));
    final p1 = _normPeriod(range.group(4)) ?? p2;
    final sh = int.parse(range.group(2)!);
    final sm = int.parse(range.group(3) ?? '0');
    final eh = int.parse(range.group(5)!);
    final em = int.parse(range.group(6) ?? '0');
    if (_valid(sh, sm) && _valid(eh, em)) {
      var s = _applyPeriod(sh, p1);
      var e = _applyPeriod(eh, p2);
      // "jam 10-1" -> 10.00-13.00
      if (e.$1 < s.$1 && e.$1 + 12 <= 24 && p2 == null) e = (e.$1 + 12, true);
      if (s.$2 && e.$1 < s.$1) s = (sh, true);
      text = text.replaceFirst(range.group(0)!, ' ');
      return TimeExtraction(time: ClockTime(s.$1, sm), endTime: ClockTime(e.$1 % 24, em), uncertain: s.$2 || e.$2, text: text);
    }
  }

  // "setengah 8" -> 07.30
  final half = RegExp('(?:\\b(?:jam|pukul)\\s*)?\\bsetengah\\s+(\\d{1,2})$_periodRe\\b').firstMatch(text);
  if (half != null) {
    final base = int.parse(half.group(1)!) - 1;
    final res = _applyPeriod(base == 0 ? 12 : base, _normPeriod(half.group(2)));
    text = text.replaceFirst(half.group(0)!, ' ');
    return TimeExtraction(time: ClockTime(res.$1, 30), uncertain: res.$2, text: text);
  }

  // "jam 10", "jam 3 sore", "pukul 15.30"
  final jam = RegExp('\\b(?:jam|pukul|pkl)\\s*(\\d{1,2})(?:[.:](\\d{2}))?$_periodRe\\b').firstMatch(text);
  if (jam != null) {
    final h = int.parse(jam.group(1)!);
    final m = int.parse(jam.group(2) ?? '0');
    if (_valid(h, m)) {
      final hasMinutesOr24 = jam.group(2) != null || h > 12;
      final res = hasMinutesOr24 && jam.group(3) == null ? (h, h >= 1 && h <= 6) : _applyPeriod(h, _normPeriod(jam.group(3)));
      text = text.replaceFirst(jam.group(0)!, ' ');
      return TimeExtraction(time: _clamp24(res.$1, m), uncertain: res.$2, text: text);
    }
  }

  // "15.00", "23:59", "7.30 pagi"
  final bare = RegExp('\\b(\\d{1,2})[.:](\\d{2})(?![.:/\\d])$_periodRe\\b').firstMatch(text);
  if (bare != null) {
    final h = int.parse(bare.group(1)!);
    final m = int.parse(bare.group(2)!);
    if (_valid(h, m)) {
      final res = bare.group(3) != null ? _applyPeriod(h, _normPeriod(bare.group(3))) : (h, false);
      text = text.replaceFirst(bare.group(0)!, ' ');
      return TimeExtraction(time: _clamp24(res.$1, m), uncertain: res.$2, text: text);
    }
  }

  final maghrib = RegExp(r"\b(abis|habis|setelah|ba'?da)\s+maghrib\b").firstMatch(text);
  if (maghrib != null) {
    return TimeExtraction(time: const ClockTime(18, 30), uncertain: true, text: text.replaceFirst(maghrib.group(0)!, ' '));
  }
  final midnight = RegExp(r'\btengah malam\b').firstMatch(text);
  if (midnight != null) {
    return TimeExtraction(time: const ClockTime(23, 59), text: text.replaceFirst(midnight.group(0)!, ' '));
  }
  return TimeExtraction(text: text);
}

// ---------------------------------------------------------------------------
// Tanggal

class DateExtraction {
  final DateTime? date;

  /// Jam default dari ungkapan seperti "nanti malam".
  final ClockTime? impliedTime;
  final bool uncertain;
  final String text;
  const DateExtraction({this.date, this.impliedTime, this.uncertain = false, required this.text});
}

DateTime _nextWeekday(DateTime now, int dow) {
  final today = startOfDay(now);
  return addDays(today, (dow - today.weekday + 7) % 7);
}

DateTime _weekdayInNextWeek(DateTime now, int dow) => addDays(addDays(startOfWeek(now), 7), dow - 1);

/// Kalau tanggal sudah lewat lebih dari seminggu, anggap tahun depan.
int _inferYear(DateTime now, int month, int day) {
  final candidate = DateTime(now.year, month, day);
  return candidate.isBefore(addDays(startOfDay(now), -7)) ? now.year + 1 : now.year;
}

DateExtraction extractDate(String input, DateTime now) {
  final text = ' $input ';
  final today = startOfDay(now);
  String take(RegExpMatch m) => text.replaceFirst(m.group(0)!, ' ');
  RegExpMatch? m;

  if ((m = RegExp(r'\b(nanti|ntar)?\s*(malam|malem)\s+ini\b|\bnanti\s+(malam|malem)\b|\bntar\s+(malam|malem)\b').firstMatch(text)) != null) {
    return DateExtraction(date: today, impliedTime: const ClockTime(19, 0), text: take(m!));
  }
  if ((m = RegExp(r'\b(hari ini|hr ini|today|sekarang)\b').firstMatch(text)) != null) {
    return DateExtraction(date: today, text: take(m!));
  }
  if ((m = RegExp(r'\b(besok|besuk|bsk|besoknya)\b').firstMatch(text)) != null) {
    return DateExtraction(date: addDays(today, 1), text: take(m!));
  }
  if ((m = RegExp(r'\b(lusa)\b').firstMatch(text)) != null) {
    return DateExtraction(date: addDays(today, 2), text: take(m!));
  }
  // "5 november", "5 nov 2026"
  if ((m = RegExp('\\b(?:tgl|tanggal)?\\s*(\\d{1,2})\\s+$_monthRe\\b(?:\\s+(\\d{4}))?').firstMatch(text)) != null) {
    final day = int.parse(m!.group(1)!);
    final month = _monthIndex(m.group(2)!);
    final year = m.group(3) != null ? int.parse(m.group(3)!) : _inferYear(now, month, day);
    return DateExtraction(date: DateTime(year, month, day), text: take(m));
  }
  // "5/11", "5/11/2026"
  if ((m = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b').firstMatch(text)) != null) {
    final day = int.parse(m!.group(1)!);
    final month = int.parse(m.group(2)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      var year = m.group(3) != null ? int.parse(m.group(3)!) : _inferYear(now, month, day);
      if (year < 100) year += 2000;
      return DateExtraction(date: DateTime(year, month, day), text: take(m));
    }
  }
  // "tgl 12"
  if ((m = RegExp(r'\b(?:tgl|tanggal)\s*(\d{1,2})\b').firstMatch(text)) != null) {
    final day = int.parse(m!.group(1)!);
    var date = DateTime(now.year, now.month, day);
    if (date.isBefore(today)) date = DateTime(now.year, now.month + 1, day);
    return DateExtraction(date: date, text: take(m));
  }
  // "kamis minggu depan"
  if ((m = RegExp('\\b(?:hari\\s+)?$_weekdayRe\\s+(?:minggu|pekan)\\s+depan\\b').firstMatch(text)) != null) {
    return DateExtraction(date: _weekdayInNextWeek(now, _weekdayOf(m!.group(1)!)!), text: take(m));
  }
  // "minggu depan" saja -> Senin depan, perlu dicek
  if ((m = RegExp(r'\b(minggu|pekan)\s+depan\b').firstMatch(text)) != null) {
    return DateExtraction(date: addDays(startOfWeek(now), 7), uncertain: true, text: take(m!));
  }
  if ((m = RegExp(r'\b(akhir\s+bulan)\b').firstMatch(text)) != null) {
    return DateExtraction(date: DateTime(now.year, now.month + 1, 0), text: take(m!));
  }
  if ((m = RegExp(r'\b(akhir\s+(minggu|pekan)|minggu\s+ini|weekend)\b').firstMatch(text)) != null) {
    return DateExtraction(date: addDays(startOfWeek(now), 6), uncertain: m!.group(1) == 'weekend', text: take(m));
  }
  // "kamis depan" -> minggu berikutnya; "kamis" -> kamis terdekat (termasuk hari ini)
  if ((m = RegExp('\\b(?:hari\\s+)?$_weekdayRe(\\s+depan)?\\b(?!\\s+(?:lalu|kemarin))').firstMatch(text)) != null) {
    final dow = _weekdayOf(m!.group(1)!);
    if (dow != null) {
      final date = m.group(2) != null ? _weekdayInNextWeek(now, dow) : _nextWeekday(now, dow);
      return DateExtraction(date: date, text: take(m));
    }
  }
  return DateExtraction(text: text);
}

// ---------------------------------------------------------------------------
// Pengulangan

class RecurrenceExtraction {
  final Recurrence? recurrence;
  final int? weekday;
  final String text;
  const RecurrenceExtraction({this.recurrence, this.weekday, required this.text});
}

RecurrenceExtraction extractRecurrence(String input) {
  final text = ' $input ';
  RegExpMatch? m;
  String take(RegExpMatch m) => text.replaceFirst(m.group(0)!, ' ');
  if ((m = RegExp(r'\b(?:tiap|setiap)\s+(?:2|dua)\s+minggu(?:\s+sekali)?\b|\b(?:2|dua)\s+minggu\s+sekali\b').firstMatch(text)) != null) {
    return RecurrenceExtraction(recurrence: const Recurrence(RecurrenceFreq.duaMingguan), text: take(m!));
  }
  if ((m = RegExp('\\b(?:tiap|setiap)\\s+(?:hari\\s+)?$_weekdayRe\\b').firstMatch(text)) != null) {
    // "tiap minggu" lebih sering berarti "tiap pekan" daripada "tiap hari Minggu".
    if (m!.group(1) == 'minggu' && !RegExp(r'hari\s+minggu').hasMatch(m.group(0)!)) {
      return RecurrenceExtraction(recurrence: const Recurrence(RecurrenceFreq.mingguan), text: take(m));
    }
    return RecurrenceExtraction(recurrence: const Recurrence(RecurrenceFreq.mingguan), weekday: _weekdayOf(m.group(1)!), text: take(m));
  }
  if ((m = RegExp(r'\b(?:tiap|setiap)\s+hari\s+kerja\b|\b(?:tiap|setiap)\s+(?:hari|hr)\b').firstMatch(text)) != null) {
    return RecurrenceExtraction(recurrence: const Recurrence(RecurrenceFreq.harian), text: take(m!));
  }
  if ((m = RegExp(r'\b(?:tiap|setiap)\s+pekan\b|\bseminggu\s+sekali\b').firstMatch(text)) != null) {
    return RecurrenceExtraction(recurrence: const Recurrence(RecurrenceFreq.mingguan), text: take(m!));
  }
  if ((m = RegExp(r'\b(?:tiap|setiap)\s+bulan\b|\bsebulan\s+sekali\b').firstMatch(text)) != null) {
    return RecurrenceExtraction(recurrence: const Recurrence(RecurrenceFreq.bulanan), text: take(m!));
  }
  return RecurrenceExtraction(text: text);
}

// ---------------------------------------------------------------------------
// Judul

String _titleCase(List<String> words) {
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (_casing.containsKey(w)) {
      out.add(_casing[w]!);
    } else if (i == 0 && w.isNotEmpty) {
      out.add(w[0].toUpperCase() + w.substring(1));
    } else {
      out.add(w);
    }
  }
  return out.join(' ');
}

String cleanTitle(String text) {
  final words = text.replaceAll(RegExp(r'[!?.,;:"()]+'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // Buang kata pengisi hanya di awal dan akhir, supaya "rapat sama dosen" tetap utuh.
  while (words.isNotEmpty && _filler.contains(words.first)) {
    words.removeAt(0);
  }
  while (words.isNotEmpty && _filler.contains(words.last)) {
    words.removeLast();
  }
  return _titleCase(words);
}

// ---------------------------------------------------------------------------
// Satu kegiatan

bool _hasDateOrTimeCue(String s) =>
    RegExp(r'\b(jam|pukul|setengah|besok|lusa|hari ini|nanti|tgl|tanggal|tiap|setiap|minggu depan|akhir bulan)\b').hasMatch(s) ||
    RegExp('\\b$_weekdayRe\\b').hasMatch(s) ||
    RegExp(r'\b\d{1,2}[.:/]\d{1,2}\b').hasMatch(s) ||
    RegExp('\\b\\d{1,2}\\s+$_monthRe\\b').hasMatch(s);

Draft _parseOne(String raw, DateTime now) {
  var s = ' ${raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')} ';
  final uncertain = <DraftField>{};

  // Zona waktu
  var tzShiftHours = 0;
  final tz = RegExp(r'\b(wib|wita|wit)\b').firstMatch(s);
  if (tz != null) {
    final stated = tz.group(1) == 'wib' ? 7 : (tz.group(1) == 'wita' ? 8 : 9);
    tzShiftHours = now.timeZoneOffset.inHours - stated;
    s = s.replaceFirst(tz.group(0)!, ' ');
  }

  // Prioritas
  var priority = Priority.sedang;
  if (RegExp(r'\b(penting|urgent|urgen|prioritas tinggi|wajib)\b|!!').hasMatch(s)) {
    priority = Priority.tinggi;
    s = s.replaceAll(RegExp(r'\b(penting banget|penting|urgent|urgen|prioritas tinggi)\b|!!+'), ' ');
  } else if (RegExp(r'\b(santai|prioritas rendah|ga penting|nggak penting)\b').hasMatch(s)) {
    priority = Priority.rendah;
    s = s.replaceAll(RegExp(r'\b(santai|prioritas rendah|ga penting|nggak penting)\b'), ' ');
  }

  // Seharian
  var allDay = false;
  final allDayRe = RegExp(r'\b(seharian|full day|sehari penuh|all day)\b');
  if (allDayRe.hasMatch(s)) {
    allDay = true;
    s = s.replaceAll(allDayRe, ' ');
  }

  final rec = extractRecurrence(s);
  s = rec.text;
  final t = extractTime(s);
  s = t.text;
  if (t.uncertain) uncertain.add(DraftField.jam);
  final d = extractDate(s, now);
  s = d.text;
  if (d.uncertain) uncertain.add(DraftField.tanggal);

  var date = d.date;
  if (date == null && rec.weekday != null) date = _nextWeekday(now, rec.weekday!);
  if (date == null && rec.recurrence?.freq == RecurrenceFreq.harian) date = startOfDay(now);
  final time = t.time ?? d.impliedTime;

  // Jenis
  final lower = raw.toLowerCase();
  final isDeadline = _deadlineWords.hasMatch(lower) || (_taskWords.hasMatch(lower) && t.endTime == null && rec.recurrence == null);
  final kind = isDeadline ? ScheduleKind.deadline : ScheduleKind.acara;
  s = s.replaceAll(_deadlineWords, ' ');

  // Kategori
  CategoryId? category;
  for (final (id, re) in _categoryWords) {
    if (re.hasMatch(lower)) {
      category = id;
      break;
    }
  }
  if (category == null) {
    category = kind == ScheduleKind.deadline ? CategoryId.tugas : CategoryId.pribadi;
    uncertain.add(DraftField.kategori);
  }

  // Lokasi: "di <tempat>" atau "@tempat" di akhir kalimat
  String? location;
  final loc = RegExp(r'\s(?:di|@)\s*([a-z0-9][\w\s.-]*?)\s*$').firstMatch(s);
  if (loc != null) {
    final place = loc.group(1)!.trim();
    if (place.length > 1 && !RegExp(r'^(scele|siak|rumah aja)$').hasMatch(place)) {
      final cased = _titleCase(place.split(RegExp(r'\s+')));
      location = cased[0].toUpperCase() + cased.substring(1);
      s = s.replaceFirst(loc.group(0)!, ' ');
    }
  }

  var title = cleanTitle(s);
  if (title.isEmpty && kind == ScheduleKind.deadline) title = 'Deadline';

  final missing = <DraftField>[
    if (title.isEmpty) DraftField.judul,
    if (date == null) DraftField.tanggal,
    if (kind == ScheduleKind.acara && time == null && !allDay) DraftField.jam,
  ];

  return Draft(
    kind: kind,
    title: title,
    date: date,
    time: kind == ScheduleKind.deadline && time == null ? const ClockTime(23, 59) : time,
    endTime: t.endTime,
    allDay: kind == ScheduleKind.acara ? allDay : false,
    category: category,
    priority: priority,
    recurrence: kind == ScheduleKind.acara ? rec.recurrence : null,
    location: location,
    tzShiftHours: tzShiftHours,
    missing: missing,
    uncertain: uncertain.toList(),
    raw: raw.trim(),
  );
}

// ---------------------------------------------------------------------------
// Pesan utuh (bisa berisi beberapa kegiatan)

final _splitRe = RegExp(r'\s*(?:\n|;|,\s*(?:terus|trus|lalu|sama|dan|plus)?\s*|\s(?:sama|terus|trus|lalu|dan juga|dan|plus|terus juga)\s)\s*');

List<String> splitActivities(String text) {
  final parts = <({String text, String sep})>[];
  var last = 0;
  var sep = '';
  for (final m in _splitRe.allMatches(text)) {
    final piece = text.substring(last, m.start).trim();
    if (piece.isNotEmpty) parts.add((text: piece, sep: sep));
    sep = m.group(0)!.trim();
    last = m.end;
  }
  final tail = text.substring(last).trim();
  if (tail.isNotEmpty) parts.add((text: tail, sep: sep));

  // Potongan dianggap kegiatan sendiri kalau punya petunjuk waktu atau kata tugas/deadline.
  // Sisanya (mis. "HIMA" di "rapat BEM dan HIMA Jumat jam 4", atau "dosen" di
  // "zoom sama dosen besok jam 1") digabung lagi ke tetangganya dengan pemisah aslinya.
  String join(String a, String sep, String b) =>
      (sep.isEmpty || sep.startsWith(',') || sep.startsWith(';')) ? '$a$sep $b' : '$a $sep $b';
  final out = <String>[];
  String? pending;
  for (final p in parts) {
    final lower = p.text.toLowerCase();
    final standalone = _hasDateOrTimeCue(lower) || _deadlineWords.hasMatch(lower) || _taskWords.hasMatch(lower);
    if (pending != null) {
      pending = join(pending, p.sep, p.text);
      if (standalone) {
        out.add(pending);
        pending = null;
      }
    } else if (standalone) {
      out.add(p.text);
    } else if (out.isNotEmpty) {
      out[out.length - 1] = join(out.last, p.sep, p.text);
    } else {
      pending = p.text;
    }
  }
  if (pending != null) out.add(pending);
  return out;
}

ParseResult parseMessage(String text, [DateTime? now]) {
  final at = now ?? DateTime.now();
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const ParseResult([], true);
  final drafts = splitActivities(trimmed).map((p) => _parseOne(p, at)).toList();

  void inherit(Draft cur, Draft from) {
    if (cur.date == null && from.date != null) {
      cur.date = from.date;
      cur.missing.remove(DraftField.tanggal);
      if (!cur.uncertain.contains(DraftField.tanggal)) cur.uncertain.add(DraftField.tanggal);
    }
  }

  // "besok kuis jam 10 sama rapat jam 4" -> rapat juga besok, dan sebaliknya.
  for (var i = 1; i < drafts.length; i++) {
    inherit(drafts[i], drafts[i - 1]);
  }
  for (var i = drafts.length - 2; i >= 0; i--) {
    inherit(drafts[i], drafts[i + 1]);
  }

  final understood = drafts
      .where((d) => d.date != null || d.time != null || d.recurrence != null || _deadlineWords.hasMatch(d.raw.toLowerCase()))
      .toList();
  if (understood.isEmpty) return const ParseResult([], true);
  return ParseResult(understood, false);
}

/// Pakai jawaban klarifikasi ("jam 10", "besok") untuk melengkapi draf.
/// Mengembalikan draf baru, atau null kalau jawabannya tidak dipahami.
Draft? applyClarification(Draft draft, String answer, [DateTime? now]) {
  final lower = ' ${answer.toLowerCase()} ';
  final t = extractTime(lower);
  final d = extractDate(t.text, now ?? DateTime.now());
  final next = draft.copy();
  var changed = false;
  if (t.time != null) {
    next.time = t.time;
    if (t.endTime != null) next.endTime = t.endTime;
    next.uncertain.remove(DraftField.jam);
    if (t.uncertain) next.uncertain.add(DraftField.jam);
    next.missing.remove(DraftField.jam);
    changed = true;
  } else if (RegExp(r'\b(seharian|full day|all day)\b').hasMatch(lower) && draft.kind == ScheduleKind.acara) {
    next.allDay = true;
    next.missing.remove(DraftField.jam);
    changed = true;
  }
  if (d.date != null) {
    next.date = d.date;
    if (d.impliedTime != null && next.time == null) next.time = d.impliedTime;
    next.missing.remove(DraftField.tanggal);
    next.uncertain.remove(DraftField.tanggal);
    changed = true;
  }
  if (draft.missing.isNotEmpty && draft.missing.first == DraftField.judul && !changed) {
    final title = cleanTitle(lower);
    if (title.isNotEmpty) {
      next.title = title;
      next.missing.remove(DraftField.judul);
      changed = true;
    }
  }
  return changed ? next : null;
}

/// Hitung waktu mulai/selesai dari draf (dengan koreksi zona waktu).
({DateTime start, DateTime? end})? draftTimes(Draft draft) {
  final date = draft.date;
  if (date == null) return null;
  final time = draft.time;
  if (draft.allDay || time == null) {
    if (draft.kind == ScheduleKind.acara && !draft.allDay) return null;
    if (draft.kind == ScheduleKind.deadline) {
      return (start: DateTime(date.year, date.month, date.day, 23, 59), end: null);
    }
    return (start: DateTime(date.year, date.month, date.day), end: DateTime(date.year, date.month, date.day, 23, 59, 59));
  }
  final start = DateTime(date.year, date.month, date.day, time.h + draft.tzShiftHours, time.m);
  if (draft.kind == ScheduleKind.deadline) return (start: start, end: null);
  DateTime end;
  final et = draft.endTime;
  if (et != null) {
    end = DateTime(date.year, date.month, date.day, et.h + draft.tzShiftHours, et.m);
    if (!end.isAfter(start)) end = addDays(end, 1);
  } else {
    end = start.add(const Duration(hours: 1));
  }
  return (start: start, end: end);
}

/// Pertanyaan klarifikasi untuk field pertama yang kosong (satu hal per pesan).
({String text, List<String> chips})? clarificationQuestion(Draft draft) {
  if (draft.missing.isEmpty) return null;
  final name = draft.title.isEmpty ? 'kegiatan ini' : draft.title;
  switch (draft.missing.first) {
    case DraftField.judul:
      return (text: 'Siap. Ini kegiatan apa? Tulis namanya ya.', chips: const <String>[]);
    case DraftField.tanggal:
      return (
        text: draft.kind == ScheduleKind.deadline ? '$name dikumpul kapan?' : '$name hari apa?',
        chips: const ['Hari ini', 'Besok', 'Lusa'],
      );
    case DraftField.jam:
      return (text: '$name jam berapa?', chips: const ['08.00', '13.00', '16.00', 'Seharian']);
    case DraftField.kategori:
      return null;
  }
}
