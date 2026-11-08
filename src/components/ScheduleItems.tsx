import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Alert, Platform, Pressable, View } from 'react-native';

import { formatCountdown, formatRelativeDay, formatShortDate, formatTime } from '@/lib/date';
import { deadlineSection } from '@/lib/occurrences';
import { deleteWithUndo, toggleDoneWithUndo, useApp, useToast } from '@/lib/store';
import type { Occurrence, Schedule } from '@/lib/types';
import { radius, useTheme } from '@/theme';

import { CategoryChip, Txt } from './ui';

/** Kartu acara di daftar agenda (Event Card). */
export function OccurrenceCard({ occ, compact }: { occ: Occurrence; compact?: boolean }) {
  const c = useTheme();
  const s = occ.schedule;
  const col = c.category[s.category];
  const isDeadline = s.kind === 'deadline';
  const time = s.allDay
    ? 'Seharian'
    : isDeadline
      ? `Tenggat ${formatTime(occ.start)}`
      : `${formatTime(occ.start)}–${formatTime(occ.end)}`;

  return (
    <Pressable
      onPress={() => router.push({ pathname: '/jadwal/[id]', params: { id: s.id, tanggal: occ.dateKey } })}
      accessibilityRole="button"
      accessibilityLabel={`${s.title}, ${time}${s.location ? `, ${s.location}` : ''}`}
      style={({ pressed }) => ({ opacity: pressed ? 0.75 : 1 })}
    >
      <View
        style={{
          flexDirection: 'row',
          borderRadius: radius.md,
          borderWidth: 1.5,
          borderColor: c.line,
          backgroundColor: col.soft,
          overflow: 'hidden',
          opacity: isDeadline && s.done ? 0.6 : 1,
        }}
      >
        <View style={{ width: 6, backgroundColor: col.solid }} />
        <View style={{ flex: 1, padding: compact ? 10 : 12, gap: 4 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            {isDeadline && <Feather name={s.done ? 'check-circle' : 'flag'} size={13} color={col.ink} />}
            <Txt variant="caption" color={col.ink}>
              {time}
            </Txt>
            {s.recurrence && <Feather name="repeat" size={12} color={col.ink} accessibilityLabel="Berulang" />}
            {s.priority === 'tinggi' && <Feather name="alert-circle" size={12} color={c.danger} accessibilityLabel="Prioritas tinggi" />}
          </View>
          <Txt
            variant="subtitle"
            numberOfLines={compact ? 1 : 2}
            style={{ textDecorationLine: isDeadline && s.done ? 'line-through' : 'none' }}
          >
            {s.title}
          </Txt>
          {!compact && s.location && (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
              <Feather name="map-pin" size={12} color={c.inkSoft} />
              <Txt variant="caption" color={c.inkSoft}>
                {s.location}
              </Txt>
            </View>
          )}
        </View>
      </View>
    </Pressable>
  );
}

function askPostpone(s: Schedule) {
  const app = useApp.getState();
  const apply = (minutes: number, label: string) => {
    app.snooze(s.id, minutes);
    useToast.getState().show(`Ditunda ke ${label}`);
  };
  const options = [
    { text: 'Besok', onPress: () => apply(1440, 'besok') },
    { text: '3 hari', onPress: () => apply(4320, '3 hari lagi') },
    { text: 'Ubah tanggal…', onPress: () => router.push({ pathname: '/jadwal/form', params: { id: s.id } }) },
    { text: 'Hapus', style: 'destructive' as const, onPress: () => deleteWithUndo(s.id) },
    { text: 'Batal', style: 'cancel' as const },
  ];
  if (Platform.OS === 'web') {
    // Alert multi-tombol tidak didukung di web; langsung buka form.
    router.push({ pathname: '/jadwal/form', params: { id: s.id } });
    return;
  }
  Alert.alert(s.title, 'Mau diapain?', options);
}

/** Item di tab Deadline: checkbox bulat, judul, kategori, tenggat, prioritas. */
export function DeadlineItem({ s, now = new Date() }: { s: Schedule; now?: Date }) {
  const c = useTheme();
  const due = new Date(s.start);
  const section = deadlineSection(s, now);
  const sub =
    section === 'terlambat'
      ? formatCountdown(due, now)
      : section === 'hari-ini'
        ? `${formatCountdown(due, now)} · ${formatTime(due)}`
        : section === 'besok'
          ? `Besok · ${formatTime(due)}`
          : `${formatShortDate(due)} · ${formatTime(due)}`;
  const late = section === 'terlambat';

  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        paddingVertical: 12,
        paddingRight: 4,
        paddingLeft: 12,
        borderRadius: radius.md,
        borderWidth: 1.5,
        borderLeftWidth: s.priority === 'tinggi' ? 6 : 1.5,
        borderColor: late ? c.danger : c.line,
        backgroundColor: late ? c.dangerSoft : c.surface,
      }}
    >
      <Pressable
        onPress={() => toggleDoneWithUndo(s.id)}
        accessibilityRole="checkbox"
        accessibilityState={{ checked: s.done }}
        accessibilityLabel={s.done ? `Batalkan selesai ${s.title}` : `Tandai selesai ${s.title}`}
        hitSlop={10}
        style={{
          width: 28,
          height: 28,
          borderRadius: 14,
          borderWidth: 2,
          borderColor: s.done ? c.success : c.line,
          backgroundColor: s.done ? c.success : 'transparent',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {s.done && <Feather name="check" size={16} color="#FFFFFF" />}
      </Pressable>
      <Pressable
        style={{ flex: 1, gap: 4 }}
        onPress={() => router.push({ pathname: '/jadwal/[id]', params: { id: s.id } })}
        accessibilityRole="button"
        accessibilityLabel={`${s.title}, ${sub}`}
      >
        <Txt variant="subtitle" numberOfLines={2} style={{ textDecorationLine: s.done ? 'line-through' : 'none' }} muted={s.done}>
          {s.title}
        </Txt>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <CategoryChip id={s.category} small />
          <Txt variant="caption" color={late ? c.danger : c.inkSoft}>
            {s.done && s.doneAt ? `Selesai ${formatRelativeDay(new Date(s.doneAt), now).toLowerCase()}` : sub}
          </Txt>
          {s.reminders.length > 0 && !s.done && <Feather name="bell" size={12} color={c.inkMuted} accessibilityLabel="Ada pengingat" />}
        </View>
      </Pressable>
      {!s.done && (
        <Pressable
          onPress={() => askPostpone(s)}
          accessibilityRole="button"
          accessibilityLabel={`Opsi untuk ${s.title}`}
          hitSlop={6}
          style={{ width: 40, height: 44, alignItems: 'center', justifyContent: 'center' }}
        >
          <Feather name="more-vertical" size={20} color={c.inkSoft} />
        </Pressable>
      )}
    </View>
  );
}
