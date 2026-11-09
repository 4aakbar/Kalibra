import 'package:flutter_test/flutter_test.dart';
import 'package:kalibra/core/dates.dart';
import 'package:kalibra/core/models.dart';
import 'package:kalibra/core/occurrences.dart';

final now = DateTime(2026, 11, 4, 10); // Rabu 4 Nov 2026
var _n = 0;

Schedule make({
  ScheduleKind kind = ScheduleKind.acara,
  DateTime? start,
  DateTime? end,
  Recurrence? recurrence,
  List<String> exdates = const [],
  bool done = false,
  DateTime? doneAt,
}) =>
    Schedule(
      id: 's${_n++}',
      kind: kind,
      title: 'X',
      start: start ?? DateTime(2026, 11, 2, 8),
      end: kind == ScheduleKind.deadline ? null : (end ?? DateTime(2026, 11, 2, 9, 40)),
      category: CategoryId.kuliah,
      recurrence: recurrence,
      exdates: exdates,
      done: done,
      doneAt: doneAt,
      createdAt: now,
      updatedAt: now,
    );

void main() {
  test('memecah jadwal mingguan dan melewati exdate (libur UTS)', () {
    final kuliah = make(recurrence: const Recurrence(RecurrenceFreq.mingguan, until: '2026-12-14'), exdates: ['2026-11-16']);
    final occ = occurrencesInRange([kuliah], DateTime(2026, 11, 1), DateTime(2026, 12, 31));
    expect(occ.map((o) => o.dateKey), ['2026-11-02', '2026-11-09', '2026-11-23', '2026-11-30', '2026-12-07', '2026-12-14']);
    expect(occ.first.end.difference(occ.first.start), const Duration(minutes: 100));
  });

  test('jadwal tunggal hanya muncul di rentangnya', () {
    final s = make();
    expect(occurrencesInRange([s], DateTime(2026, 11, 3), DateTime(2026, 11, 10)), isEmpty);
    expect(occurrencesInRange([s], DateTime(2026, 11, 2), DateTime(2026, 11, 2, 23)), hasLength(1));
  });

  test('jadwal bulanan di tanggal 31 jatuh ke akhir bulan lalu kembali ke 31', () {
    final s = make(start: DateTime(2026, 1, 31, 9), end: DateTime(2026, 1, 31, 10), recurrence: const Recurrence(RecurrenceFreq.bulanan));
    final occ = occurrencesInRange([s], DateTime(2026, 2, 1), DateTime(2026, 3, 31, 23));
    expect(occ.map((o) => dateKey(o.start)), ['2026-02-28', '2026-03-31']);
  });

  test('mengelompokkan deadline per bagian', () {
    Schedule d(int day, {bool done = false}) => make(
          kind: ScheduleKind.deadline,
          start: DateTime(2026, 11, day, 23, 59),
          done: done,
          doneAt: done ? now : null,
        );
    final list = [d(3), d(4), d(5), d(8), d(20), d(6, done: true)];
    final groups = groupDeadlines(list, now).map((k, v) => MapEntry(k, v.length));
    expect(groups, {
      DeadlineSection.terlambat: 1,
      DeadlineSection.hariIni: 1,
      DeadlineSection.besok: 1,
      DeadlineSection.mingguIni: 1,
      DeadlineSection.nanti: 1,
      DeadlineSection.selesai: 1,
    });
    expect(deadlineBadgeCount(list, now), 2);
  });

  test('Schedule bisa disimpan sebagai JSON', () {
    final s = make(recurrence: const Recurrence(RecurrenceFreq.mingguan, until: '2026-12-14'), exdates: ['2026-11-16']);
    final back = Schedule.fromJson(s.toJson());
    expect(back.start, s.start);
    expect(back.end, s.end);
    expect(back.recurrence, s.recurrence);
    expect(back.exdates, s.exdates);
  });
}
