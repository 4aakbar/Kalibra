import { useColorScheme } from 'react-native';

import { useApp } from '@/lib/store';
import type { CategoryId } from '@/lib/types';

/**
 * Design token Kalibra. Arah visual: kertas krem hangat + indigo brand, aksen kategori
 * yang cerah, garis tegas dan bayangan keras kecil (editorial), bukan gradien ungu
 * di atas hitam. Dark mode memakai arang hangat, teks krem, dan indigo yang dicerahkan.
 */
export interface Palette {
  scheme: 'light' | 'dark';
  bg: string;
  surface: string;
  surfaceAlt: string;
  ink: string;
  inkSoft: string;
  inkMuted: string;
  line: string;
  shadow: string;
  primary: string;
  primarySoft: string;
  onPrimary: string;
  accent: string;
  danger: string;
  dangerSoft: string;
  success: string;
  successSoft: string;
  warning: string;
  warningSoft: string;
  category: Record<CategoryId, { solid: string; soft: string; ink: string }>;
}

const light: Palette = {
  scheme: 'light',
  bg: '#FFF9F0',
  surface: '#FFFFFF',
  surfaceAlt: '#FFF1DE',
  ink: '#1F1B16',
  inkSoft: '#4A4239',
  inkMuted: '#7D7366',
  line: '#1F1B16',
  shadow: '#1F1B16',
  primary: '#3B2BD0',
  primarySoft: '#E7E3FF',
  onPrimary: '#FFFFFF',
  accent: '#9B6BFF',
  danger: '#D93B2B',
  dangerSoft: '#FFE3DE',
  success: '#17855A',
  successSoft: '#DDF5E9',
  warning: '#9A6A00',
  warningSoft: '#FFF0C2',
  category: {
    kuliah: { solid: '#2E8FE0', soft: '#DCEEFF', ink: '#0B4C86' },
    tugas: { solid: '#FF6B57', soft: '#FFE4DF', ink: '#9A2617' },
    organisasi: { solid: '#F5B700', soft: '#FFF2C7', ink: '#7A5800' },
    magang: { solid: '#1FB27E', soft: '#D9F6EA', ink: '#0B6A47' },
    pribadi: { solid: '#9B6BFF', soft: '#EEE6FF', ink: '#5222C2' },
  },
};

const dark: Palette = {
  scheme: 'dark',
  bg: '#1F1C19',
  surface: '#2A2622',
  surfaceAlt: '#35302A',
  ink: '#FFF4E3',
  inkSoft: '#E5D9C6',
  inkMuted: '#B3A794',
  line: '#5A5147',
  shadow: '#000000',
  primary: '#7A6DFF',
  primarySoft: '#3A3466',
  onPrimary: '#FFFFFF',
  accent: '#B79BFF',
  danger: '#FF7A6B',
  dangerSoft: '#4A2A25',
  success: '#5BD6A0',
  successSoft: '#1F3D30',
  warning: '#F5C84B',
  warningSoft: '#43381C',
  category: {
    kuliah: { solid: '#5AB0F5', soft: '#1E3448', ink: '#B9DEFF' },
    tugas: { solid: '#FF8C7A', soft: '#4A2A25', ink: '#FFD0C7' },
    organisasi: { solid: '#F7C83A', soft: '#43381C', ink: '#FFE9A6' },
    magang: { solid: '#4FD1A0', soft: '#1F3D30', ink: '#B8F2DA' },
    pribadi: { solid: '#B79BFF', soft: '#362C55', ink: '#E2D6FF' },
  },
};

export const fonts = {
  display: 'BricolageGrotesque_700Bold',
  displayHeavy: 'BricolageGrotesque_800ExtraBold',
  body: 'PlusJakartaSans_400Regular',
  medium: 'PlusJakartaSans_500Medium',
  semibold: 'PlusJakartaSans_600SemiBold',
  bold: 'PlusJakartaSans_700Bold',
};

export const radius = { sm: 8, md: 14, lg: 20, pill: 999 };
export const space = (n: number) => n * 4;

export function useTheme(): Palette {
  const system = useColorScheme();
  const pref = useApp((s) => s.prefs.theme);
  const scheme = pref === 'sistem' ? (system === 'dark' ? 'dark' : 'light') : pref === 'gelap' ? 'dark' : 'light';
  return scheme === 'dark' ? dark : light;
}

/** Bayangan keras kecil ala editorial (offset tanpa blur). */
export function hardShadow(c: Palette, offset = 3) {
  return {
    shadowColor: c.shadow,
    shadowOffset: { width: offset, height: offset },
    shadowOpacity: c.scheme === 'dark' ? 0.6 : 1,
    shadowRadius: 0,
    elevation: 0,
  } as const;
}
