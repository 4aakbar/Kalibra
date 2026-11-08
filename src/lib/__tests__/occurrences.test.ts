import { dateKey } from '../date';
import { deadlineBadgeCount, groupDeadlines, occurrencesInRange } from '../occurrences';
import type { Schedule } from '../types';

const NOW = new Date(2026, 10, 4, 10, 0); // Rabu 4 Nov 2026

function make(p: Partial<Schedule>): Schedule {
  return {
    id: Math.random().toString(36).slice(2),
    kind: 'acara',
    title: 'X',
    start: new Date(2026, 10, 2, 8, 0).toISOString(),
    end: new Date(2026, 10, 2, 9, 40).toISOString(),
    allDay: false,
    category: 'kuliah',
    priority: 'sedang',
    exdates: [],
    reminders: [],
    done: false,
    source: 'manual',
    createdAt: NOW.toISOString(),
    updatedAt: NOW.toISOString(),
    ...p,
  };
}

describe('occurrencesInRange', () => {
  it('memecah jadwal mingguan dan melewati exdate (libur UTS)', () => {
    const kuliah = make({ recurrence: { freq: 'mingguan', until: '2026-12-14' }, exdates: ['2026-11-16'] });
    const occ = occurrencesInRange([kuliah], new Date(2026, 10, 1), new Date(2026, 11, 31));
    expect(occ.map((o) => o.dateKey)).toEqual(['2026-11-02', '2026-11-09', '2026-11-23', '2026-11-30', '2026-12-07', '2026-12-14']);
    expect(occ[0].end.getTime() - occ[0].start.getTime()).toBe(100 * 60_000);
  });

  it('jadwal tunggal hanya muncul di rentangnya', () => {
    const s = make({});
    expect(occurrencesInRange([s], new Date(2026, 10, 3), new Date(2026, 10, 10))).toHaveLength(0);
    expect(occurrencesInRange([s], new Date(2026, 10, 2), new Date(2026, 10, 2, 23))).toHaveLength(1);
  });

  it('jadwal bulanan di tanggal 31 jatuh ke akhir bulan', () => {
    const s = make({ start: new Date(2026, 0, 31, 9).toISOString(), end: undefined, recurrence: { freq: 'bulanan' } });
    const occ = occurrencesInRange([s], new Date(2026, 1, 1), new Date(2026, 1, 28, 23));
    expect(occ.map((o) => dateKey(o.start))).toEqual(['2026-02-28']);
  });
});

describe('groupDeadlines', () => {
  const d = (day: number, h = 23, extra: Partial<Schedule> = {}) =>
    make({ kind: 'deadline', end: undefined, start: new Date(2026, 10, day, h, 59).toISOString(), ...extra });

  it('mengelompokkan Terlambat, Hari ini, Besok, Minggu ini, Nanti, Selesai', () => {
    const list = [d(3), d(4), d(5), d(8), d(20), d(6, 23, { done: true, doneAt: NOW.toISOString() })];
    const groups = Object.fromEntries(groupDeadlines(list, NOW).map((g) => [g.key, g.data.length]));
    expect(groups).toEqual({ terlambat: 1, 'hari-ini': 1, besok: 1, 'minggu-ini': 1, nanti: 1, selesai: 1 });
    expect(deadlineBadgeCount(list, NOW)).toBe(2);
  });
});
