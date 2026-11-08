/**
 * Utilitas tanggal untuk konteks Indonesia: minggu mulai Senin, jam 24 jam (15.00),
 * nama hari dan bulan Bahasa Indonesia. Sengaja tidak bergantung pada Intl supaya
 * hasilnya sama di Hermes, web, dan Node (tes).
 */

export const HARI = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
export const HARI_SINGKAT = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
export const BULAN = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
export const BULAN_SINGKAT = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

const pad = (n: number) => String(n).padStart(2, '0');

export function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function endOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
}

export function addDays(d: Date, n: number): Date {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}

export function addMonths(d: Date, n: number): Date {
  const r = new Date(d);
  const day = r.getDate();
  r.setDate(1);
  r.setMonth(r.getMonth() + n);
  const last = new Date(r.getFullYear(), r.getMonth() + 1, 0).getDate();
  r.setDate(Math.min(day, last));
  return r;
}

export function addMinutes(d: Date, n: number): Date {
  return new Date(d.getTime() + n * 60_000);
}

/** Senin dari minggu tanggal d. */
export function startOfWeek(d: Date): Date {
  const s = startOfDay(d);
  const dow = (s.getDay() + 6) % 7; // Senin = 0
  return addDays(s, -dow);
}

export function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

export function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export function dateKey(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function fromDateKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function diffDays(a: Date, b: Date): number {
  return Math.round((startOfDay(a).getTime() - startOfDay(b).getTime()) / 86_400_000);
}

/** "15.00" */
export function formatTime(d: Date): string {
  return `${pad(d.getHours())}.${pad(d.getMinutes())}`;
}

/** "Kamis, 5 November 2026" */
export function formatLongDate(d: Date): string {
  return `${HARI[d.getDay()]}, ${d.getDate()} ${BULAN[d.getMonth()]} ${d.getFullYear()}`;
}

/** "Kam, 5 Nov" */
export function formatShortDate(d: Date): string {
  return `${HARI_SINGKAT[d.getDay()]}, ${d.getDate()} ${BULAN_SINGKAT[d.getMonth()]}`;
}

/** "Hari ini", "Besok", "Kemarin", atau "Kam, 5 Nov". */
export function formatRelativeDay(d: Date, now = new Date()): string {
  const diff = diffDays(d, now);
  if (diff === 0) return 'Hari ini';
  if (diff === 1) return 'Besok';
  if (diff === 2) return 'Lusa';
  if (diff === -1) return 'Kemarin';
  return formatShortDate(d);
}

export function monthTitle(d: Date): string {
  return `${BULAN[d.getMonth()]} ${d.getFullYear()}`;
}

/** "07:30" -> menit sejak tengah malam */
export function hhmmToMinutes(s: string): number {
  const [h, m] = s.split(':').map(Number);
  return h * 60 + (m || 0);
}

export function minutesToHHMM(min: number): string {
  return `${pad(Math.floor(min / 60))}:${pad(min % 60)}`;
}

/** Sisa waktu ringkas: "4 jam lagi", "Lewat 2 hari". */
export function formatCountdown(target: Date, now = new Date()): string {
  const ms = target.getTime() - now.getTime();
  const abs = Math.abs(ms);
  const min = Math.round(abs / 60_000);
  let unit: string;
  if (min < 60) unit = `${Math.max(min, 1)} menit`;
  else if (min < 60 * 24) unit = `${Math.round(min / 60)} jam`;
  else unit = `${Math.round(min / 1440)} hari`;
  return ms >= 0 ? `${unit} lagi` : `Lewat ${unit}`;
}

/** Grid bulan 6x7 mulai Senin. */
export function monthGrid(d: Date): Date[] {
  const first = startOfWeek(startOfMonth(d));
  return Array.from({ length: 42 }, (_, i) => addDays(first, i));
}
