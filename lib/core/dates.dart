/// Utilitas tanggal konteks Indonesia: minggu mulai Senin, jam 24 jam (15.00),
/// nama hari dan bulan Bahasa Indonesia.
library;

const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const hariSingkat = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const bulanSingkat = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _pad(int n) => n.toString().padLeft(2, '0');

/// Nama hari untuk DateTime.weekday (1 = Senin ... 7 = Minggu).
String dayName(DateTime d) => hari[d.weekday - 1];
String dayShort(DateTime d) => hariSingkat[d.weekday - 1];

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Tambah hari secara kalender (aman terhadap pergantian jam musim panas).
DateTime addDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute, d.second, d.millisecond);

DateTime addMonths(DateTime d, int n) {
  final first = DateTime(d.year, d.month + n, 1);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day > last ? last : d.day, d.hour, d.minute);
}

/// Senin dari minggu tanggal d.
DateTime startOfWeek(DateTime d) => addDays(startOfDay(d), -(d.weekday - 1));
DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

DateTime fromDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

int diffDays(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

/// "15.00"
String formatTime(DateTime d) => '${_pad(d.hour)}.${_pad(d.minute)}';

/// "Kamis, 5 November 2026"
String formatLongDate(DateTime d) => '${dayName(d)}, ${d.day} ${bulan[d.month - 1]} ${d.year}';

/// "Kam, 5 Nov"
String formatShortDate(DateTime d) => '${dayShort(d)}, ${d.day} ${bulanSingkat[d.month - 1]}';

String formatRelativeDay(DateTime d, [DateTime? now]) {
  final diff = diffDays(d, now ?? DateTime.now());
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Besok';
  if (diff == 2) return 'Lusa';
  if (diff == -1) return 'Kemarin';
  return formatShortDate(d);
}

String monthTitle(DateTime d) => '${bulan[d.month - 1]} ${d.year}';

int hhmmToMinutes(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + (p.length > 1 ? int.parse(p[1]) : 0);
}

/// "4 jam lagi", "Lewat 2 hari"
String formatCountdown(DateTime target, [DateTime? now]) {
  final ms = target.difference(now ?? DateTime.now()).inMilliseconds;
  final min = (ms.abs() / 60000).round();
  final String unit;
  if (min < 60) {
    unit = '${min < 1 ? 1 : min} menit';
  } else if (min < 60 * 24) {
    unit = '${(min / 60).round()} jam';
  } else {
    unit = '${(min / 1440).round()} hari';
  }
  return ms >= 0 ? '$unit lagi' : 'Lewat $unit';
}

/// Grid bulan 6x7 mulai Senin.
List<DateTime> monthGrid(DateTime d) {
  final first = startOfWeek(startOfMonth(d));
  return List.generate(42, (i) => addDays(first, i));
}
