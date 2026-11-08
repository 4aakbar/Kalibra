import { useEffect } from 'react';
import { Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useToast } from '@/lib/store';
import { radius, useTheme } from '@/theme';

import { Txt } from './ui';

/** Toast di atas tab bar selama 5 detik, untuk aksi yang bisa diurungkan. */
export function ToastHost({ bottomOffset = 96 }: { bottomOffset?: number }) {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const { message, actionLabel, onAction, hide, key } = useToast();

  useEffect(() => {
    if (!message) return;
    const t = setTimeout(hide, 5000);
    return () => clearTimeout(t);
  }, [key, message, hide]);

  if (!message) return null;
  return (
    <View
      pointerEvents="box-none"
      style={{ position: 'absolute', left: 16, right: 16, bottom: insets.bottom + bottomOffset, alignItems: 'center' }}
    >
      <View
        accessibilityLiveRegion="polite"
        accessibilityRole="alert"
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: 12,
          paddingLeft: 16,
          paddingRight: 6,
          minHeight: 48,
          borderRadius: radius.pill,
          backgroundColor: c.ink,
          maxWidth: 440,
          width: '100%',
        }}
      >
        <Txt variant="subtitle" color={c.bg} style={{ flex: 1, fontSize: 15 }}>
          {message}
        </Txt>
        {actionLabel && (
          <Pressable
            onPress={() => {
              onAction?.();
              hide();
            }}
            accessibilityRole="button"
            style={{ paddingHorizontal: 14, minHeight: 40, justifyContent: 'center', borderRadius: radius.pill, backgroundColor: c.category.organisasi.solid }}
          >
            <Txt variant="label" color="#1F1B16">
              {actionLabel}
            </Txt>
          </Pressable>
        )}
      </View>
    </View>
  );
}
