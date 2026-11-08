import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { TabHeader } from '@/components/Header';
import { DeadlineItem } from '@/components/ScheduleItems';
import { Button, Card, CategoryChip, Chip, EmptyState, Screen, Txt } from '@/components/ui';
import { CATEGORIES } from '@/lib/categories';
import { addDays } from '@/lib/date';
import { useFormPrefill } from '@/lib/formPrefill';
import { requestPermission } from '@/lib/notifications';
import type { DeadlineSection } from '@/lib/occurrences';
import { groupDeadlines } from '@/lib/occurrences';
import { useApp } from '@/lib/store';
import type { CategoryId } from '@/lib/types';
import { radius, useTheme } from '@/theme';

type Filter = 'semua' | 'tinggi' | CategoryId;

export default function DeadlineScreen() {
  const c = useTheme();
  const schedules = useApp((s) => s.schedules);
  const notificationsEnabled = useApp((s) => s.prefs.notificationsEnabled);
  const setPrefs = useApp((s) => s.setPrefs);
  const [filter, setFilter] = useState<Filter>('semua');
  const [collapsed, setCollapsed] = useState<Partial<Record<DeadlineSection, boolean>>>({ selesai: true });
  const now = new Date();

  const deadlines = schedules.filter((s) => s.kind === 'deadline');
  const filtered = useMemo(
    () =>
      deadlines.filter((s) => (filter === 'semua' ? true : filter === 'tinggi' ? s.priority === 'tinggi' : s.category === filter)),
    [deadlines, filter],
  );
  const groups = groupDeadlines(filtered, now);

  // Ringkasan: deadline 7 hari ke depan, dan progres di jendela 7 hari ke belakang s/d 7 hari ke depan.
  const weekAhead = addDays(now, 7).getTime();
  const windowStart = addDays(now, -7).getTime();
  const inWindow = deadlines.filter((s) => {
    const t = new Date(s.start).getTime();
    return t >= windowStart && t < weekAhead;
  });
  const doneInWindow = inWindow.filter((s) => s.done).length;
  const lateCount = groups.find((g) => g.key === 'terlambat')?.data.length ?? 0;
  const openAhead = deadlines.filter((s) => !s.done && new Date(s.start).getTime() >= now.getTime() && new Date(s.start).getTime() < weekAhead).length;

  const openForm = () => {
    useFormPrefill.getState().set({ input: { kind: 'deadline', category: 'tugas', source: 'manual' } });
    router.push('/jadwal/form');
  };

  return (
    <Screen>
      <TabHeader title="Deadline" />
      <ScrollView contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 100, gap: 14 }}>
        {!notificationsEnabled && (
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: 10,
              padding: 12,
              borderRadius: radius.md,
              backgroundColor: c.warningSoft,
              borderWidth: 1.5,
              borderColor: c.warning,
            }}
          >
            <Feather name="bell-off" size={18} color={c.warning} />
            <Txt style={{ flex: 1 }} color={c.ink}>
              Pengingat mati. Nyalakan biar nggak kelewat.
            </Txt>
            <Button
              label="Nyalakan"
              small
              kind="secondary"
              onPress={async () => setPrefs({ notificationsEnabled: await requestPermission() })}
            />
          </View>
        )}

        {deadlines.length > 0 && (
          <Card color={c.primary} style={{ gap: 10 }}>
            <Txt variant="title" color="#FFFFFF">
              {openAhead} deadline 7 hari ke depan{lateCount ? ` · ${lateCount} terlambat` : ''}
            </Txt>
            <View style={{ height: 12, borderRadius: 6, backgroundColor: 'rgba(255,255,255,0.25)', overflow: 'hidden' }}>
              <View
                style={{
                  width: `${inWindow.length ? (doneInWindow / inWindow.length) * 100 : 0}%`,
                  height: '100%',
                  backgroundColor: c.category.organisasi.solid,
                }}
              />
            </View>
            <Txt variant="label" color="#FFFFFF">
              {doneInWindow} dari {inWindow.length} selesai (2 minggu ini)
            </Txt>
          </Card>
        )}

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
          <Chip label="Semua" selected={filter === 'semua'} onPress={() => setFilter('semua')} />
          <Chip label="Prioritas tinggi" icon="alert-circle" selected={filter === 'tinggi'} onPress={() => setFilter('tinggi')} />
          {CATEGORIES.map((cat) => (
            <CategoryChip key={cat.id} id={cat.id} selected={filter === cat.id} onPress={() => setFilter(filter === cat.id ? 'semua' : cat.id)} />
          ))}
        </ScrollView>

        {deadlines.length === 0 ? (
          <EmptyState
            icon="check-square"
            title="Nggak ada deadline"
            body={`Santai dulu, atau ketik di Chat: "TK SDA dikumpul Jumat 23.59"`}
            action={{ label: 'Buka Chat', onPress: () => router.push({ pathname: '/chat', params: { isi: 'TK SDA dikumpul Jumat 23.59' } }) }}
          />
        ) : inWindow.length > 0 && openAhead === 0 && lateCount === 0 && doneInWindow === inWindow.length && filter === 'semua' ? (
          <Card color={c.successSoft} style={{ alignItems: 'center', gap: 6 }}>
            <Txt variant="title">Semua beres!</Txt>
            <Txt muted>Mantap. Deadline berikutnya ada di bagian Nanti.</Txt>
          </Card>
        ) : null}

        {groups
          .filter((g) => g.data.length)
          .map((g) => (
            <View key={g.key} style={{ gap: 8 }}>
              <Pressable
                onPress={() => setCollapsed((s) => ({ ...s, [g.key]: !s[g.key] }))}
                accessibilityRole="button"
                accessibilityState={{ expanded: !collapsed[g.key] }}
                style={{ flexDirection: 'row', alignItems: 'center', gap: 8, paddingVertical: 4 }}
              >
                <Txt variant="title" color={g.key === 'terlambat' ? c.danger : c.ink}>
                  {g.title}
                </Txt>
                <View style={{ paddingHorizontal: 8, borderRadius: radius.pill, backgroundColor: c.surfaceAlt }}>
                  <Txt variant="caption">{g.data.length}</Txt>
                </View>
                <View style={{ flex: 1 }} />
                <Feather name={collapsed[g.key] ? 'chevron-down' : 'chevron-up'} size={20} color={c.inkMuted} />
              </Pressable>
              {!collapsed[g.key] && g.data.map((s) => <DeadlineItem key={s.id} s={s} now={now} />)}
            </View>
          ))}
      </ScrollView>

      <Pressable onPress={openForm} accessibilityRole="button" accessibilityLabel="Tambah deadline manual" style={{ position: 'absolute', right: 20, bottom: 20 }}>
        <View style={{ position: 'absolute', left: 3, top: 3, width: 56, height: 56, borderRadius: 18, backgroundColor: c.scheme === 'dark' ? '#000' : c.shadow, opacity: c.scheme === 'dark' ? 0.5 : 1 }} />
        <View style={{ width: 56, height: 56, borderRadius: 18, backgroundColor: c.category.tugas.solid, borderWidth: 1.5, borderColor: c.line, alignItems: 'center', justifyContent: 'center' }}>
          <Feather name="plus" size={26} color="#1F1B16" />
        </View>
      </Pressable>
    </Screen>
  );
}
