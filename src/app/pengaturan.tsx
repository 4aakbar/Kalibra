import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { Alert, Linking, Platform, ScrollView, Switch, View } from 'react-native';

import { StackHeader } from '@/components/Header';
import { Card, Chip, ListRow, Screen, Segmented, Txt } from '@/components/ui';
import { REMINDER_OPTIONS } from '@/lib/categories';
import { requestPermission } from '@/lib/notifications';
import { useApp, useToast } from '@/lib/store';
import type { CalendarView, ThemePreference } from '@/lib/types';
import { useTheme } from '@/theme';

export default function Pengaturan() {
  const c = useTheme();
  const prefs = useApp((s) => s.prefs);
  const setPrefs = useApp((s) => s.setPrefs);
  const clearChat = useApp((s) => s.clearChat);

  const confirmClearChat = () => {
    const go = () => {
      clearChat();
      useToast.getState().show('Riwayat chat dihapus');
    };
    if (Platform.OS === 'web') return go();
    Alert.alert('Hapus semua riwayat chat?', 'Jadwal yang sudah tersimpan tidak ikut terhapus.', [
      { text: 'Batal', style: 'cancel' },
      { text: 'Hapus', style: 'destructive', onPress: go },
    ]);
  };

  return (
    <Screen>
      <StackHeader title="Pengaturan" />
      <ScrollView contentContainerStyle={{ padding: 20, gap: 22, paddingBottom: 60 }}>
        <Group title="Pengingat & notifikasi">
          <ListRow
            icon={prefs.notificationsEnabled ? 'bell' : 'bell-off'}
            label="Izin notifikasi"
            right={
              <Switch
                value={prefs.notificationsEnabled}
                trackColor={{ true: c.primary }}
                accessibilityLabel="Izin notifikasi"
                onValueChange={async (v) => {
                  if (!v) return setPrefs({ notificationsEnabled: false });
                  const ok = await requestPermission();
                  setPrefs({ notificationsEnabled: ok });
                  if (!ok && Platform.OS !== 'web') {
                    Alert.alert('Izin ditolak', 'Nyalakan notifikasi Kalibra di pengaturan HP.', [
                      { text: 'Nanti', style: 'cancel' },
                      { text: 'Buka pengaturan', onPress: () => Linking.openSettings() },
                    ]);
                  }
                }}
              />
            }
          />
          <Inner label="Pengingat default acara">
            {REMINDER_OPTIONS.filter((r) => r.minutes <= 1440).map((r) => (
              <Chip key={r.minutes} label={r.label} selected={prefs.eventReminder === r.minutes} onPress={() => setPrefs({ eventReminder: r.minutes })} />
            ))}
          </Inner>
          <Inner label="Pengingat default deadline">
            {REMINDER_OPTIONS.filter((r) => r.minutes >= 180).map((r) => (
              <Chip key={r.minutes} label={r.label} selected={prefs.deadlineReminder === r.minutes} onPress={() => setPrefs({ deadlineReminder: r.minutes })} />
            ))}
          </Inner>
          <ListRow
            icon="sunrise"
            label={`Ringkasan pagi (${prefs.dayStart.replace(':', '.')})`}
            right={<Switch value={prefs.morningSummary} trackColor={{ true: c.primary }} onValueChange={(v) => setPrefs({ morningSummary: v })} accessibilityLabel="Ringkasan pagi" />}
          />
          {Platform.OS === 'android' && (
            <ListRow icon="battery" label="Panduan optimasi baterai" onPress={() => Linking.openSettings()} />
          )}
        </Group>

        <Group title="Kalender">
          <Inner label="Tampilan default">
            <View style={{ flex: 1 }}>
              <Segmented<CalendarView>
                value={prefs.calendarView}
                onChange={(v) => setPrefs({ calendarView: v })}
                options={[
                  { value: 'bulan', label: 'Bulan' },
                  { value: 'minggu', label: 'Minggu' },
                  { value: 'hari', label: 'Hari' },
                ]}
              />
            </View>
          </Inner>
          <ListRow icon="clock" label="Format jam" value="24 jam" />
          <ListRow icon="calendar" label="Awal minggu" value="Senin" />
        </Group>

        <Group title="Tampilan">
          <Inner label="Tema">
            <View style={{ flex: 1 }}>
              <Segmented<ThemePreference>
                value={prefs.theme}
                onChange={(v) => setPrefs({ theme: v })}
                options={[
                  { value: 'terang', label: 'Terang' },
                  { value: 'gelap', label: 'Gelap' },
                  { value: 'sistem', label: 'Ikuti sistem' },
                ]}
              />
            </View>
          </Inner>
        </Group>

        <Group title="Chat">
          <ListRow icon="trash" label="Hapus semua riwayat chat" onPress={confirmClearChat} />
        </Group>

        <Group title="Privasi & data">
          <ListRow
            icon="bar-chart-2"
            label="Izinkan analitik anonim"
            right={<Switch value={prefs.analytics} trackColor={{ true: c.primary }} onValueChange={(v) => setPrefs({ analytics: v })} accessibilityLabel="Analitik anonim" />}
          />
          <ListRow icon="shield" label="Kebijakan privasi" value="Segera" />
          <ListRow icon="user-x" label="Hapus akun" danger onPress={() => router.push('/hapus-akun')} />
        </Group>

        <Group title="Bantuan & masukan">
          <ListRow
            icon="mail"
            label="Laporkan masalah"
            onPress={() => Linking.openURL('mailto:?subject=Masukan%20Kalibra%20v0.1.0')}
          />
          <ListRow icon="info" label="Versi" value="0.1.0 (pratinjau)" />
        </Group>
      </ScrollView>
    </Screen>
  );
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={{ gap: 8 }}>
      <Txt variant="label" muted style={{ letterSpacing: 1, textTransform: 'uppercase' }}>
        {title}
      </Txt>
      <Card style={{ padding: 0, overflow: 'hidden' }}>{children}</Card>
    </View>
  );
}

function Inner({ label, children }: { label: string; children: ReactNode }) {
  return (
    <View style={{ paddingHorizontal: 14, paddingVertical: 10, gap: 8 }}>
      <Txt variant="label">{label}</Txt>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{children}</View>
    </View>
  );
}
