import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, View } from 'react-native';

import { StackHeader } from '@/components/Header';
import { Button, Card, Chip, Field, Screen, Txt } from '@/components/ui';
import { cancelAllReminders } from '@/lib/notifications';
import { useApp } from '@/lib/store';
import { useTheme } from '@/theme';

const REASONS = ['Nggak kepake lagi', 'Pindah ke app lain', 'Chat-nya kurang paham', 'Masalah privasi', 'Lainnya'];

/**
 * Hapus akun di dalam app (wajib App Store 5.1.1(v) dan Google Play).
 * Versi ini local-first, jadi semua data di perangkat langsung dihapus. Setelah backend ada,
 * alurnya menjadi soft-delete 30 hari sesuai spesifikasi.
 */
export default function HapusAkun() {
  const c = useTheme();
  const count = useApp((s) => s.schedules.length);
  const resetAll = useApp((s) => s.resetAll);
  const [reason, setReason] = useState<string>();
  const [confirm, setConfirm] = useState('');

  const remove = async () => {
    await cancelAllReminders();
    resetAll();
    router.dismissAll?.();
    router.replace('/onboarding');
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <StackHeader title="Hapus akun" />
      <ScrollView contentContainerStyle={{ padding: 20, gap: 18, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <Card color={c.dangerSoft} borderColor={c.danger} style={{ gap: 10 }}>
          <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center' }}>
            <Feather name="alert-triangle" size={20} color={c.danger} />
            <Txt variant="title" color={c.danger}>
              Ini tidak bisa dibatalkan
            </Txt>
          </View>
          <Txt>Yang akan dihapus dari perangkat ini:</Txt>
          <Txt>• {count} jadwal dan deadline{'\n'}• Semua riwayat chat{'\n'}• Preferensi dan jawaban kuesioner{'\n'}• Semua pengingat terjadwal</Txt>
        </Card>

        <View style={{ gap: 8 }}>
          <Txt variant="label">Kenapa mau pergi? (opsional)</Txt>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
            {REASONS.map((r) => (
              <Chip key={r} label={r} selected={reason === r} onPress={() => setReason(reason === r ? undefined : r)} />
            ))}
          </View>
        </View>

        <Field
          label='Ketik "HAPUS" untuk konfirmasi'
          value={confirm}
          onChangeText={setConfirm}
          autoCapitalize="characters"
          placeholder="HAPUS"
        />

        <Button label="Hapus akun permanen" kind="danger" icon="trash-2" disabled={confirm.trim().toUpperCase() !== 'HAPUS'} onPress={remove} />
        <Button label="Batal" kind="ghost" onPress={() => router.back()} />
      </ScrollView>
    </Screen>
  );
}
