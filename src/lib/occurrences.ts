import { addDays, addMonths, dateKey, diffDays, endOfDay, fromDateKey, startOfDay, startOfWeek } from './date';
import type { Occurrence, Schedule } from './types';

function durationMs(s: Schedule): number {
  if (s.kind === 'deadline' || !s.end) return 0;
  return Math.max(new Date(s.end).getTime() - new Date(s.start).getTime(), 0);
}

function step(d: Date, freq: NonNullable<Schedule['recurrence']>['freq']): Date {
  switch (freq) {
    case 'harian':
      return addDays(d, 1);
    case 'mingguan':
      return addDays(d, 7);
    case 'dua-mingguan':
      return addDays(d, 14);
    case 'bulanan':
      return addMonths(d, 1);
  }
}

/**
 * Semua kejadian jadwal yang menyentuh rentang [from, to].
 * Jadwal berulang dipecah per kejadian, kecuali tanggal yang ada di `exdates`.
 */
export function occurrencesInRange(schedules: Schedule[], from: Date, to: Date): Occurrence[] {
  const out: Occurrence[] = [];
  const fromMs = from.getTime();
  const toMs = to.getTime();
  for (const s of schedules) {
    const first = new Date(s.start);
    const dur = durationMs(s);
    const push = (start: Date) => {
      const end = new Date(start.getTime() + dur);
      if (end.getTime() >= fromMs && start.getTime() <= toMs) {
        out.push({ schedule: s, dateKey: dateKey(start), start, end });
      }
    };
    if (!s.recurrence) {
      push(first);
      continue;
    }
    const until = s.recurrence.until ? endOfDay(fromDateKey(s.recurrence.until)).getTime() : Infinity;
    let cur = first;
    // Lompat cepat mendekati rentang untuk pengulangan harian/mingguan.
    if (cur.getTime() < fromMs && s.recurrence.freq !== 'bulanan') {
      const period = s.recurrence.freq === 'harian' ? 1 : s.recurrence.freq === 'mingguan' ? 7 : 14;
      const skip = Math.floor(diffDays(from, cur) / period) - 1;
      if (skip > 0) cur = addDays(cur, skip * period);
    }
    let guard = 0;
    while (cur.getTime() <= toMs && cur.getTime() <= until && guard < 1000) {
      if (!s.exdates.includes(dateKey(cur))) push(cur);
      cur = step(cur, s.recurrence.freq);
      guard++;
    }
  }
  return out.sort((a, b) => a.start.getTime() - b.start.getTime());
}

export function occurrencesOnDay(schedules: Schedule[], day: Date): Occurrence[] {
  return occurrencesInRange(schedules, startOfDay(day), endOfDay(day));
}

export type DeadlineSection = 'terlambat' | 'hari-ini' | 'besok' | 'minggu-ini' | 'nanti' | 'selesai';

export const SECTION_LABEL: Record<DeadlineSection, string> = {
  terlambat: 'Terlambat',
  'hari-ini': 'Hari ini',
  besok: 'Besok',
  'minggu-ini': 'Minggu ini',
  nanti: 'Nanti',
  selesai: 'Selesai',
};

export function deadlineSection(s: Schedule, now = new Date()): DeadlineSection {
  if (s.done) return 'selesai';
  const due = new Date(s.start);
  if (due.getTime() < now.getTime()) return 'terlambat';
  const diff = diffDays(due, now);
  if (diff === 0) return 'hari-ini';
  if (diff === 1) return 'besok';
  const sunday = addDays(startOfWeek(now), 6);
  if (startOfDay(due).getTime() <= sunday.getTime()) return 'minggu-ini';
  return 'nanti';
}

/** Deadline dikelompokkan per bagian, masing-masing urut dari yang paling mepet. */
export function groupDeadlines(schedules: Schedule[], now = new Date()) {
  const order: DeadlineSection[] = ['terlambat', 'hari-ini', 'besok', 'minggu-ini', 'nanti', 'selesai'];
  const cutoff = addDays(now, -30).getTime();
  const groups = new Map<DeadlineSection, Schedule[]>(order.map((k) => [k, []]));
  for (const s of schedules) {
    if (s.kind !== 'deadline') continue;
    if (s.done && s.doneAt && new Date(s.doneAt).getTime() < cutoff) continue;
    groups.get(deadlineSection(s, now))!.push(s);
  }
  for (const [key, list] of groups) {
    list.sort((a, b) =>
      key === 'selesai'
        ? new Date(b.doneAt ?? b.start).getTime() - new Date(a.doneAt ?? a.start).getTime()
        : new Date(a.start).getTime() - new Date(b.start).getTime(),
    );
  }
  return order.map((key) => ({ key, title: SECTION_LABEL[key], data: groups.get(key)! }));
}

/** Badge tab Deadline: tenggat hari ini + yang terlambat. */
export function deadlineBadgeCount(schedules: Schedule[], now = new Date()): number {
  return schedules.filter((s) => {
    if (s.kind !== 'deadline' || s.done) return false;
    const sec = deadlineSection(s, now);
    return sec === 'terlambat' || sec === 'hari-ini';
  }).length;
}
