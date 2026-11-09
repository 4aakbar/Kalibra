/// Model data Kalibra. Semua bisa diubah ke/dari JSON supaya disimpan lokal
/// (local-first) dan nanti disinkron ke server.
library;

enum ScheduleKind { acara, deadline }

enum CategoryId { kuliah, tugas, organisasi, magang, pribadi }

enum Priority { rendah, sedang, tinggi }

enum RecurrenceFreq { harian, mingguan, duaMingguan, bulanan }

enum ThemePref { sistem, terang, gelap }

enum CalendarView { bulan, minggu, hari }

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

class Recurrence {
  final RecurrenceFreq freq;

  /// Tanggal terakhir (YYYY-MM-DD, inklusif). null = tidak berakhir.
  final String? until;

  const Recurrence(this.freq, {this.until});

  Map<String, dynamic> toJson() => {'freq': freq.name, 'until': until};
  factory Recurrence.fromJson(Map<String, dynamic> j) =>
      Recurrence(_enum(RecurrenceFreq.values, j['freq'], RecurrenceFreq.mingguan), until: j['until'] as String?);

  @override
  bool operator ==(Object other) => other is Recurrence && other.freq == freq && other.until == until;
  @override
  int get hashCode => Object.hash(freq, until);
  @override
  String toString() => 'Recurrence($freq, until: $until)';
}

class Schedule {
  final String id;
  final ScheduleKind kind;
  final String title;

  /// Acara: waktu mulai. Deadline: waktu tenggat.
  final DateTime start;

  /// Hanya untuk acara.
  final DateTime? end;
  final bool allDay;
  final CategoryId category;
  final Priority priority;

  /// Hanya untuk acara (MVP).
  final Recurrence? recurrence;

  /// Kejadian yang dilewati untuk jadwal berulang (YYYY-MM-DD).
  final List<String> exdates;

  /// Menit sebelum mulai/tenggat.
  final List<int> reminders;
  final String? location;
  final String? notes;
  final String? link;
  final bool done;
  final DateTime? doneAt;

  /// 'chat' atau 'manual'.
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Schedule({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    required this.category,
    this.priority = Priority.sedang,
    this.recurrence,
    this.exdates = const [],
    this.reminders = const [],
    this.location,
    this.notes,
    this.link,
    this.done = false,
    this.doneAt,
    this.source = 'manual',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDeadline => kind == ScheduleKind.deadline;

  Schedule copyWith({
    ScheduleKind? kind,
    String? title,
    DateTime? start,
    DateTime? Function()? end,
    bool? allDay,
    CategoryId? category,
    Priority? priority,
    Recurrence? Function()? recurrence,
    List<String>? exdates,
    List<int>? reminders,
    String? Function()? location,
    String? Function()? notes,
    String? Function()? link,
    bool? done,
    DateTime? Function()? doneAt,
    String? source,
    DateTime? updatedAt,
  }) =>
      Schedule(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end != null ? end() : this.end,
        allDay: allDay ?? this.allDay,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        recurrence: recurrence != null ? recurrence() : this.recurrence,
        exdates: exdates ?? this.exdates,
        reminders: reminders ?? this.reminders,
        location: location != null ? location() : this.location,
        notes: notes != null ? notes() : this.notes,
        link: link != null ? link() : this.link,
        done: done ?? this.done,
        doneAt: doneAt != null ? doneAt() : this.doneAt,
        source: source ?? this.source,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'allDay': allDay,
        'category': category.name,
        'priority': priority.name,
        'recurrence': recurrence?.toJson(),
        'exdates': exdates,
        'reminders': reminders,
        'location': location,
        'notes': notes,
        'link': link,
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
        'source': source,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        id: j['id'] as String,
        kind: _enum(ScheduleKind.values, j['kind'], ScheduleKind.acara),
        title: j['title'] as String,
        start: DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
        allDay: j['allDay'] as bool? ?? false,
        category: _enum(CategoryId.values, j['category'], CategoryId.pribadi),
        priority: _enum(Priority.values, j['priority'], Priority.sedang),
        recurrence: j['recurrence'] == null ? null : Recurrence.fromJson(Map<String, dynamic>.from(j['recurrence'] as Map)),
        exdates: List<String>.from(j['exdates'] as List? ?? const []),
        reminders: List<int>.from(j['reminders'] as List? ?? const []),
        location: j['location'] as String?,
        notes: j['notes'] as String?,
        link: j['link'] as String?,
        done: j['done'] as bool? ?? false,
        doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
        source: j['source'] as String? ?? 'manual',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// Satu kejadian di kalender (jadwal berulang dipecah jadi banyak kejadian).
class Occurrence {
  final Schedule schedule;
  final String dateKey;
  final DateTime start;
  final DateTime end;
  const Occurrence(this.schedule, this.dateKey, this.start, this.end);
}

class Preferences {
  final String nickname;
  final String email;
  final List<CategoryId> categories;
  final int eventReminder;
  final int deadlineReminder;
  final String dayStart; // "06:30"
  final String dayEnd; // "23:00"
  final int? missedFrequency;
  final String? noteHabit;
  final ThemePref theme;
  final CalendarView calendarView;
  final bool morningSummary;
  final bool notificationsEnabled;
  final bool analytics;

  const Preferences({
    this.nickname = '',
    this.email = '',
    this.categories = CategoryId.values,
    this.eventReminder = 30,
    this.deadlineReminder = 1440,
    this.dayStart = '06:30',
    this.dayEnd = '23:00',
    this.missedFrequency,
    this.noteHabit,
    this.theme = ThemePref.sistem,
    this.calendarView = CalendarView.minggu,
    this.morningSummary = true,
    this.notificationsEnabled = false,
    this.analytics = true,
  });

  Preferences copyWith({
    String? nickname,
    String? email,
    List<CategoryId>? categories,
    int? eventReminder,
    int? deadlineReminder,
    String? dayStart,
    String? dayEnd,
    int? missedFrequency,
    String? noteHabit,
    ThemePref? theme,
    CalendarView? calendarView,
    bool? morningSummary,
    bool? notificationsEnabled,
    bool? analytics,
  }) =>
      Preferences(
        nickname: nickname ?? this.nickname,
        email: email ?? this.email,
        categories: categories ?? this.categories,
        eventReminder: eventReminder ?? this.eventReminder,
        deadlineReminder: deadlineReminder ?? this.deadlineReminder,
        dayStart: dayStart ?? this.dayStart,
        dayEnd: dayEnd ?? this.dayEnd,
        missedFrequency: missedFrequency ?? this.missedFrequency,
        noteHabit: noteHabit ?? this.noteHabit,
        theme: theme ?? this.theme,
        calendarView: calendarView ?? this.calendarView,
        morningSummary: morningSummary ?? this.morningSummary,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        analytics: analytics ?? this.analytics,
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'email': email,
        'categories': categories.map((c) => c.name).toList(),
        'eventReminder': eventReminder,
        'deadlineReminder': deadlineReminder,
        'dayStart': dayStart,
        'dayEnd': dayEnd,
        'missedFrequency': missedFrequency,
        'noteHabit': noteHabit,
        'theme': theme.name,
        'calendarView': calendarView.name,
        'morningSummary': morningSummary,
        'notificationsEnabled': notificationsEnabled,
        'analytics': analytics,
      };

  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
        nickname: j['nickname'] as String? ?? '',
        email: j['email'] as String? ?? '',
        categories: (j['categories'] as List? ?? CategoryId.values.map((c) => c.name).toList())
            .map((n) => _enum(CategoryId.values, n, CategoryId.pribadi))
            .toList(),
        eventReminder: j['eventReminder'] as int? ?? 30,
        deadlineReminder: j['deadlineReminder'] as int? ?? 1440,
        dayStart: j['dayStart'] as String? ?? '06:30',
        dayEnd: j['dayEnd'] as String? ?? '23:00',
        missedFrequency: j['missedFrequency'] as int?,
        noteHabit: j['noteHabit'] as String?,
        theme: _enum(ThemePref.values, j['theme'], ThemePref.sistem),
        calendarView: _enum(CalendarView.values, j['calendarView'], CalendarView.minggu),
        morningSummary: j['morningSummary'] as bool? ?? true,
        notificationsEnabled: j['notificationsEnabled'] as bool? ?? false,
        analytics: j['analytics'] as bool? ?? true,
      );
}
