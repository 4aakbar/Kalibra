import { Feather } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { Alert, Linking, Platform, ScrollView, View } from 'react-native';

import { StackHeader } from '@/components/Header';
import { Button, Card, CategoryChip, EmptyState, Screen, Txt } from '@/components/ui';
import type { IconName } from '@/components/ui';
import { PRIORITY_LABEL, reminderLabel } from '@/lib/categories';
import { formatLongDate, formatShortDate, formatTime, fromDateKey } from '@/lib/date';
import { deleteWithUndo, toggleDoneWithUndo, useApp, useToast } from '@/lib/store';
import { useTheme } from '@/theme';

const FREQ = { harian: 'Setiap hari', mingguan: 'Setiap minggu', 'dua-mingguan': 'Setiap 2 minggu', bulanan: 'Setiap bulan' };

export default function DetailJadwal() {
  const c = useTheme();
  const { id, tanggal } = useLocalSearchParams<{ id: string; tanggal?: string }>();
  const s = useApp((st) => st.schedules.find((x) => x.id === id));
  const addSchedule = useApp((st) => st.addSchedule);
  const skipOccurrence = useApp((st) => st.skipOccurrence);

  if (!s) {
    return (
      <Screen>
        <StackHeader title="Detail" />
        <EmptyState icon="slash" title="Jadwal nggak ditemukan" body="Mungkin sudah dihapus." action={{ label: 'Kembali', onPress: () => router.back() }} />
      </Screen>
    );
  }

  // Waktu kejadian yang dibuka (untuk jadwal berulang).
  const baseStart = new Date(s.start);
  const start = tanggal && s.recurrence ? (() => {
    const d = fromDateKey(tanggal);
    d.setHours(baseStart.getHours(), baseStart.getMinutes());
    return d;
  })() : baseStart;
  const end = s.end ? new Date(start.getTime() + (new Date(s.end).getTime() - baseStart.getTime())) : undefined;
  const col = c.category[s.category];

  const when = s.allDay
    ? `${formatLongDate(start)} · Seharian`
    : s.kind === 'deadline'
      ? `${formatLongDate(start)} · tenggat ${formatTime(start)}`
      : `${formatLongDate(start)} · ${formatTime(start)}–${formatTime(end!)}`;

  const remove = () => {
    if (s.recurrence && tanggal) {
      const onlyThis = () => {
        skipOccurrence(s.id, tanggal);
        useToast.getState().show('Kejadian ini dihapus', {
          label: 'Urungkan',
          onPress: () => useApp.getState().updateSchedule(s.id, { exdates: s.exdates }),
        });
        router.back();
      };
      const all = () => {
        deleteWithUndo(s.id);
        router.back();
      };
      if (Platform.OS === 'web') return onlyThis();
      Alert.alert('Hapus jadwal berulang', 'Mau hapus yang mana?', [
        { text: 'Hanya kejadian ini', onPress: onlyThis },
        { text: 'Semua kejadian', style: 'destructive', onPress: all },
        { text: 'Batal', style: 'cancel' },
      ]);
      return;
    }
    deleteWithUndo(s.id);
    router.back();
  };

  const duplicate = () => {
    const { id: _id, createdAt: _c, updatedAt: _u, done: _d, doneAt: _da, ...rest } = s;
    const copy = addSchedule({ ...rest, title: `${s.title} (salinan)`, source: 'manual' });
    useToast.getState().show('Jadwal diduplikat');
    router.replace({ pathname: '/jadwal/[id]', params: { id: copy.id } });
  };

  return (
    <Screen>
      <StackHeader title={s.kind === 'deadline' ? 'Detail deadline' : 'Detail jadwal'} />
      <ScrollView contentContainerStyle={{ padding: 20, gap: 16, paddingBottom: 40 }}>
        <Card color={col.soft} style={{ gap: 10, padding: 18 }}>
          <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <CategoryChip id={s.category} small />
            {s.priority !== 'sedang' && (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                <Feather name="flag" size={12} color={s.priority === 'tinggi' ? c.danger : c.inkMuted} />
                <Txt variant="caption" color={s.priority === 'tinggi' ? c.danger : c.inkMuted}>
                  Prioritas {PRIORITY_LABEL[s.priority].toLowerCase()}
                </Txt>
              </View>
            )}
            {s.done && (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                <Feather name="check-circle" size={12} color={c.success} />
                <Txt variant="caption" color={c.success}>
                  Selesai
                </Txt>
              </View>
            )}
          </View>
          <Txt variant="display" style={{ textDecorationLine: s.done ? 'line-through' : 'none' }}>
            {s.title}
          </Txt>
        </Card>

        <Card style={{ gap: 14 }}>
          <Info icon="calendar" label="Waktu" value={when} />
          {s.recurrence && (
            <Info
              icon="repeat"
              label="Pengulangan"
              value={`${FREQ[s.recurrence.freq]}${s.recurrence.until ? ` sampai ${formatShortDate(fromDateKey(s.recurrence.until))}` : ''}${s.exdates.length ? ` · ${s.exdates.length} dilewati` : ''}`}
            />
          )}
          {s.location && <Info icon="map-pin" label="Lokasi" value={s.location} />}
          {s.link && <Info icon="link" label="Link" value={s.link} onPress={() => Linking.openURL(s.link!.startsWith('http') ? s.link! : `https://${s.link}`)} />}
          {s.notes && <Info icon="file-text" label="Catatan" value={s.notes} />}
          <Info
            icon="bell"
            label="Pengingat"
            value={s.reminders.length ? s.reminders.map(reminderLabel).join(', ') : 'Tidak ada'}
          />
          <Info
            icon={s.source === 'chat' ? 'message-circle' : 'edit-3'}
            label="Sumber"
            value={`Dibuat lewat ${s.source === 'chat' ? 'chat' : 'form'}, ${formatShortDate(new Date(s.createdAt))} ${formatTime(new Date(s.createdAt))}`}
          />
        </Card>

        <View style={{ gap: 10 }}>
          {s.kind === 'deadline' && (
            <Button
              label={s.done ? 'Batalkan selesai' : 'Tandai selesai'}
              icon={s.done ? 'rotate-ccw' : 'check'}
              onPress={() => toggleDoneWithUndo(s.id)}
            />
          )}
          <View style={{ flexDirection: 'row', gap: 10, flexWrap: 'wrap' }}>
            <Button
              label="Edit"
              icon="edit-2"
              kind="secondary"
              small
              onPress={() => router.push({ pathname: '/jadwal/form', params: { id: s.id, tanggal: tanggal ?? '' } })}
            />
            <Button label="Duplikat" icon="copy" kind="secondary" small onPress={duplicate} />
            <Button label="Hapus" icon="trash-2" kind="danger" small onPress={remove} />
          </View>
        </View>
      </ScrollView>
    </Screen>
  );
}

function Info({ icon, label, value, onPress }: { icon: IconName; label: string; value: string; onPress?: () => void }) {
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', gap: 12 }}>
      <Feather name={icon} size={18} color={c.primary} style={{ marginTop: 2 }} />
      <View style={{ flex: 1 }}>
        <Txt variant="caption" muted>
          {label}
        </Txt>
        <Txt onPress={onPress} color={onPress ? c.primary : c.ink} style={{ textDecorationLine: onPress ? 'underline' : 'none' }}>
          {value}
        </Txt>
      </View>
    </View>
  );
}
