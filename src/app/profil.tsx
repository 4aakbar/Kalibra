import { router } from 'expo-router';
import { Alert, Platform, ScrollView, View } from 'react-native';

import { Avatar, StackHeader } from '@/components/Header';
import { Card, ListRow, Screen, Txt } from '@/components/ui';
import { addDays, startOfWeek } from '@/lib/date';
import { cancelAllReminders } from '@/lib/notifications';
import { useApp } from '@/lib/store';
import { radius, useTheme } from '@/theme';

export default function Profil() {
  const c = useTheme();
  const prefs = useApp((s) => s.prefs);
  const schedules = useApp((s) => s.schedules);
  const resetAll = useApp((s) => s.resetAll);

  const monday = startOfWeek(new Date());
  const inWeek = (iso: string) => {
    const t = new Date(iso).getTime();
    return t >= monday.getTime() && t < addDays(monday, 7).getTime();
  };
  const savedThisWeek = schedules.filter((s) => inWeek(s.createdAt)).length;
  const viaChat = schedules.filter((s) => inWeek(s.createdAt) && s.source === 'chat').length;
  const onTime = schedules.filter((s) => s.kind === 'deadline' && s.done && s.doneAt && inWeek(s.doneAt) && new Date(s.doneAt) <= new Date(s.start)).length;
  const isUI = /@(ui\.ac\.id|[a-z]+\.ui\.ac\.id)$/i.test(prefs.email);

  const logout = () => {
    const go = async () => {
      await cancelAllReminders();
      resetAll();
      router.replace('/onboarding');
    };
    if (Platform.OS === 'web') return go();
    Alert.alert('Keluar dari Kalibra?', 'Di versi ini data hanya ada di HP, jadi keluar akan menghapus semua jadwal di perangkat ini.', [
      { text: 'Batal', style: 'cancel' },
      { text: 'Keluar', style: 'destructive', onPress: go },
    ]);
  };

  return (
    <Screen>
      <StackHeader title="Profil" />
      <ScrollView contentContainerStyle={{ padding: 20, gap: 18, paddingBottom: 40 }}>
        <Card style={{ flexDirection: 'row', alignItems: 'center', gap: 14, padding: 18 }}>
          <Avatar size={64} />
          <View style={{ flex: 1, gap: 2 }}>
            <Txt variant="title">{prefs.nickname || 'Teman Kalibra'}</Txt>
            {!!prefs.email && <Txt muted>{prefs.email}</Txt>}
            <View style={{ flexDirection: 'row', gap: 6, marginTop: 4, flexWrap: 'wrap' }}>
              <Badge label="Gratis" color={c.surfaceAlt} />
              {isUI && <Badge label="Mahasiswa UI" color={c.category.organisasi.soft} />}
            </View>
          </View>
        </Card>

        {!prefs.notificationsEnabled && (
          <Card color={c.warningSoft} borderColor={c.warning} offset={0}>
            <Txt>Pengingat masih mati. Nyalakan di Pengaturan biar deadline nggak kelewat.</Txt>
          </Card>
        )}

        <View style={{ gap: 8 }}>
          <Txt variant="label" muted style={{ letterSpacing: 1 }}>
            MINGGU INI
          </Txt>
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <Stat value={savedThisWeek} label="jadwal disimpan" color={c.category.kuliah.soft} />
            <Stat value={onTime} label="deadline tepat waktu" color={c.category.magang.soft} />
            <Stat value={viaChat} label="dibuat lewat chat" color={c.category.pribadi.soft} />
          </View>
        </View>

        <Card style={{ padding: 0, overflow: 'hidden' }}>
          <ListRow icon="settings" label="Pengaturan" onPress={() => router.push('/pengaturan')} />
          <ListRow icon="help-circle" label="Bantuan & masukan" onPress={() => router.push('/pengaturan')} />
          <ListRow icon="info" label="Tentang Kalibra" value="v0.1.0" />
          <ListRow icon="log-out" label="Keluar" danger onPress={logout} />
        </Card>
      </ScrollView>
    </Screen>
  );
}

function Badge({ label, color }: { label: string; color: string }) {
  const c = useTheme();
  return (
    <View style={{ paddingHorizontal: 8, paddingVertical: 2, borderRadius: radius.pill, backgroundColor: color, borderWidth: 1, borderColor: c.line }}>
      <Txt variant="caption">{label}</Txt>
    </View>
  );
}

function Stat({ value, label, color }: { value: number; label: string; color: string }) {
  return (
    <Card color={color} style={{ flex: 1, gap: 2, padding: 12 }}>
      <Txt variant="display">{value}</Txt>
      <Txt variant="caption">{label}</Txt>
    </Card>
  );
}
