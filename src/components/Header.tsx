import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { Pressable, View } from 'react-native';

import { useApp } from '@/lib/store';
import { fonts, useTheme } from '@/theme';

import { IconButton, Txt } from './ui';

export function Avatar({ size = 40, onPress }: { size?: number; onPress?: () => void }) {
  const c = useTheme();
  const name = useApp((s) => s.prefs.nickname);
  const needsAttention = useApp((s) => !s.prefs.notificationsEnabled);
  const initial = (name.trim()[0] ?? 'K').toUpperCase();
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      accessibilityRole="button"
      accessibilityLabel={needsAttention ? 'Profil, ada yang perlu dicek' : 'Profil'}
      hitSlop={6}
    >
      <View
        style={{
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: c.category.organisasi.solid,
          borderWidth: 1.5,
          borderColor: c.line,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Txt style={{ fontFamily: fonts.displayHeavy, fontSize: size * 0.45, lineHeight: size * 0.55 }} color="#1F1B16">
          {initial}
        </Txt>
      </View>
      {needsAttention && onPress && (
        <View
          style={{
            position: 'absolute',
            right: -1,
            top: -1,
            width: 12,
            height: 12,
            borderRadius: 6,
            backgroundColor: c.danger,
            borderWidth: 2,
            borderColor: c.bg,
          }}
        />
      )}
    </Pressable>
  );
}

/** Header bersama tiga tab: judul kiri, Cari, lalu avatar profil di kanan atas. */
export function TabHeader({ title, subtitle, extra }: { title: string; subtitle?: string; extra?: ReactNode }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingTop: 8, paddingBottom: 8 }}>
      <View style={{ flex: 1 }}>
        {subtitle && (
          <Txt variant="label" muted>
            {subtitle}
          </Txt>
        )}
        <Txt variant="display" accessibilityRole="header">
          {title}
        </Txt>
      </View>
      {extra}
      <IconButton icon="search" label="Cari jadwal" onPress={() => router.push('/cari')} />
      <View style={{ width: 6 }} />
      <Avatar onPress={() => router.push('/profil')} />
    </View>
  );
}

/** Header layar dalam (tanpa tab bar) dengan tombol kembali. */
export function StackHeader({ title, right }: { title: string; right?: ReactNode }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, paddingVertical: 6, gap: 4 }}>
      <IconButton icon="arrow-left" label="Kembali" onPress={() => (router.canGoBack() ? router.back() : router.replace('/kalender'))} />
      <Txt variant="title" style={{ flex: 1 }} numberOfLines={1} accessibilityRole="header">
        {title}
      </Txt>
      {right}
    </View>
  );
}
