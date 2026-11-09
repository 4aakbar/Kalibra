import 'dates.dart';
import 'models.dart';

Duration _duration(Schedule s) =>
    s.isDeadline || s.end == null ? Duration.zero : (s.end!.isAfter(s.start) ? s.end!.difference(s.start) : Duration.zero);

DateTime _step(DateTime d, RecurrenceFreq f) => switch (f) {
      RecurrenceFreq.harian => addDays(d, 1),
      RecurrenceFreq.mingguan => addDays(d, 7),
      RecurrenceFreq.duaMingguan => addDays(d, 14),
      RecurrenceFreq.bulanan => addMonths(d, 1),
    };

/// Semua kejadian yang menyentuh rentang [from, to]. Jadwal berulang dipecah
/// per kejadian, kecuali tanggal yang ada di exdates.
List<Occurrence> occurrencesInRange(List<Schedule> schedules, DateTime from, DateTime to) {
  final out = <Occurrence>[];
  for (final s in schedules) {
    final dur = _duration(s);
    void push(DateTime start) {
      final end = start.add(dur);
      if (!end.isBefore(from) && !start.isAfter(to)) out.add(Occurrence(s, dateKey(start), start, end));
    }

    final rec = s.recurrence;
    if (rec == null) {
      push(s.start);
      continue;
    }
    final until = rec.until == null ? null : endOfDay(fromDateKey(rec.until!));
    var cur = s.start;
    // Lompat cepat mendekati rentang untuk pengulangan harian/mingguan.
    if (cur.isBefore(from) && rec.freq != RecurrenceFreq.bulanan) {
      final period = switch (rec.freq) { RecurrenceFreq.harian => 1, RecurrenceFreq.mingguan => 7, _ => 14 };
      final skip = diffDays(from, cur) ~/ period - 1;
      if (skip > 0) cur = addDays(cur, skip * period);
    }
    var guard = 0;
    final firstDay = s.start.day;
    while (!cur.isAfter(to) && (until == null || !cur.isAfter(until)) && guard < 1000) {
      if (!s.exdates.contains(dateKey(cur))) push(cur);
      cur = _step(cur, rec.freq);
      // Bulanan: kembali ke tanggal asli kalau bulan berikutnya cukup panjang (31 Jan -> 28 Feb -> 31 Mar).
      if (rec.freq == RecurrenceFreq.bulanan && cur.day != firstDay) {
        final last = DateTime(cur.year, cur.month + 1, 0).day;
        cur = DateTime(cur.year, cur.month, firstDay > last ? last : firstDay, cur.hour, cur.minute);
      }
      guard++;
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

List<Occurrence> occurrencesOnDay(List<Schedule> schedules, DateTime day) =>
    occurrencesInRange(schedules, startOfDay(day), endOfDay(day));

enum DeadlineSection { terlambat, hariIni, besok, mingguIni, nanti, selesai }

const sectionLabel = {
  DeadlineSection.terlambat: 'Terlambat',
  DeadlineSection.hariIni: 'Hari ini',
  DeadlineSection.besok: 'Besok',
  DeadlineSection.mingguIni: 'Minggu ini',
  DeadlineSection.nanti: 'Nanti',
  DeadlineSection.selesai: 'Selesai',
};

DeadlineSection deadlineSection(Schedule s, [DateTime? now]) {
  final n = now ?? DateTime.now();
  if (s.done) return DeadlineSection.selesai;
  if (s.start.isBefore(n)) return DeadlineSection.terlambat;
  final diff = diffDays(s.start, n);
  if (diff == 0) return DeadlineSection.hariIni;
  if (diff == 1) return DeadlineSection.besok;
  final sunday = addDays(startOfWeek(n), 6);
  if (!startOfDay(s.start).isAfter(sunday)) return DeadlineSection.mingguIni;
  return DeadlineSection.nanti;
}

/// Deadline per bagian, masing-masing urut dari yang paling mepet.
Map<DeadlineSection, List<Schedule>> groupDeadlines(List<Schedule> schedules, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final cutoff = addDays(n, -30);
  final groups = {for (final k in DeadlineSection.values) k: <Schedule>[]};
  for (final s in schedules) {
    if (!s.isDeadline) continue;
    if (s.done && s.doneAt != null && s.doneAt!.isBefore(cutoff)) continue;
    groups[deadlineSection(s, n)]!.add(s);
  }
  groups.forEach((key, list) {
    if (key == DeadlineSection.selesai) {
      list.sort((a, b) => (b.doneAt ?? b.start).compareTo(a.doneAt ?? a.start));
    } else {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
  });
  return groups;
}

/// Badge tab Deadline: tenggat hari ini + yang terlambat.
int deadlineBadgeCount(List<Schedule> schedules, [DateTime? now]) => schedules.where((s) {
      if (!s.isDeadline || s.done) return false;
      final sec = deadlineSection(s, now);
      return sec == DeadlineSection.terlambat || sec == DeadlineSection.hariIni;
    }).length;
