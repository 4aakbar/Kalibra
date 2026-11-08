import { useMemo, useState } from 'react';
import { ScrollView, View } from 'react-native';

import { StackHeader } from '@/components/Header';
import { OccurrenceCard } from '@/components/ScheduleItems';
import { Chip, EmptyState, Field, Screen, Txt } from '@/components/ui';
import { dateKey } from '@/lib/date';
import { useApp } from '@/lib/store';
import type { Occurrence, Schedule, ScheduleKind } from '@/lib/types';

/** Pencarian di data lokal (jalan offline): judul, lokasi, catatan. */
export default function Cari() {
  const schedules = useApp((s) => s.schedules);
  const [q, setQ] = useState('');
  const [kind, setKind] = useState<ScheduleKind | 'semua'>('semua');

  const results = useMemo(() => {
    const term = q.trim().toLowerCase();
    if (!term) return { upcoming: [], past: [] };
    const match = (s: Schedule) =>
      (kind === 'semua' || s.kind === kind) &&
      [s.title, s.location, s.notes].some((f) => f?.toLowerCase().includes(term));
    const now = Date.now();
    const toOcc = (s: Schedule): Occurrence => {
      const start = new Date(s.start);
      return { schedule: s, dateKey: dateKey(start), start, end: s.end ? new Date(s.end) : start };
    };
    const found = schedules.filter(match).map(toOcc);
    return {
      upcoming: found.filter((o) => o.end.getTime() >= now || o.schedule.recurrence).sort((a, b) => a.start.getTime() - b.start.getTime()),
      past: found.filter((o) => o.end.getTime() < now && !o.schedule.recurrence).sort((a, b) => b.start.getTime() - a.start.getTime()),
    };
  }, [q, kind, schedules]);

  return (
    <Screen>
      <StackHeader title="Cari" />
      <View style={{ paddingHorizontal: 20, gap: 10 }}>
        <Field value={q} onChangeText={setQ} placeholder="Cari judul, lokasi, catatan" autoFocus returnKeyType="search" accessibilityLabel="Cari" />
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Chip label="Semua" selected={kind === 'semua'} onPress={() => setKind('semua')} />
          <Chip label="Acara" selected={kind === 'acara'} onPress={() => setKind('acara')} />
          <Chip label="Deadline" selected={kind === 'deadline'} onPress={() => setKind('deadline')} />
        </View>
      </View>
      <ScrollView contentContainerStyle={{ padding: 20, gap: 10 }} keyboardShouldPersistTaps="handled">
        {q.trim() && !results.upcoming.length && !results.past.length && (
          <EmptyState icon="search" title="Nggak ketemu" body={`Belum ada jadwal yang cocok dengan "${q.trim()}".`} />
        )}
        {results.upcoming.length > 0 && <Txt variant="label" muted>MENDATANG</Txt>}
        {results.upcoming.map((o) => (
          <OccurrenceCard key={o.schedule.id} occ={o} />
        ))}
        {results.past.length > 0 && <Txt variant="label" muted style={{ marginTop: 8 }}>SUDAH LEWAT</Txt>}
        {results.past.map((o) => (
          <OccurrenceCard key={o.schedule.id} occ={o} />
        ))}
      </ScrollView>
    </Screen>
  );
}
