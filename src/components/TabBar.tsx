import { Feather } from '@expo/vector-icons';
import type { BottomTabBarProps } from 'expo-router/js-tabs';
import { Pressable, View } from 'react-native';

import { deadlineBadgeCount } from '@/lib/occurrences';
import { useApp } from '@/lib/store';
import { radius, useTheme } from '@/theme';

import type { IconName } from './ui';
import { Txt } from './ui';

const META: Record<string, { label: string; icon: IconName }> = {
  kalender: { label: 'Kalender', icon: 'calendar' },
  chat: { label: 'Chat', icon: 'message-circle' },
  deadline: { label: 'Deadline', icon: 'check-square' },
};

/** Tab bar: Kalender (kiri), Chat (tengah, bulat, menonjol), Deadline (kanan, dengan badge). */
export function TabBar({ state, navigateToTab, insets }: BottomTabBarProps) {
  const c = useTheme();
  const schedules = useApp((s) => s.schedules);
  const badge = deadlineBadgeCount(schedules);

  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'flex-end',
        paddingBottom: Math.max(insets.bottom, 10),
        paddingTop: 8,
        paddingHorizontal: 24,
        backgroundColor: c.bg,
        borderTopWidth: 1.5,
        borderTopColor: c.line,
      }}
      accessibilityRole="tablist"
    >
      {state.routes.map((route, index) => {
        const meta = META[route.name];
        if (!meta) return null;
        const focused = state.index === index;
        const isChat = route.name === 'chat';
        const color = focused ? c.primary : c.inkMuted;

        if (isChat) {
          return (
            <Pressable
              key={route.key}
              onPress={() => navigateToTab(route.key)}
              accessibilityRole="tab"
              accessibilityState={{ selected: focused }}
              accessibilityLabel="Chat, buat jadwal"
              style={{ flex: 1, alignItems: 'center' }}
            >
              <View style={{ marginTop: -30 }}>
                <View
                  style={{
                    position: 'absolute',
                    left: 3,
                    top: 3,
                    width: 64,
                    height: 64,
                    borderRadius: 32,
                    backgroundColor: c.scheme === 'dark' ? '#000' : c.shadow,
                    opacity: c.scheme === 'dark' ? 0.5 : 1,
                  }}
                />
                <View
                  style={{
                    width: 64,
                    height: 64,
                    borderRadius: 32,
                    backgroundColor: c.primary,
                    borderWidth: 1.5,
                    borderColor: c.line,
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Feather name="message-circle" size={28} color="#FFFFFF" />
                </View>
              </View>
              <Txt variant="caption" color={focused ? c.primary : c.inkSoft} style={{ marginTop: 4, fontFamily: focused ? 'PlusJakartaSans_700Bold' : undefined }}>
                {meta.label}
              </Txt>
            </Pressable>
          );
        }

        return (
          <Pressable
            key={route.key}
            onPress={() => navigateToTab(route.key)}
            accessibilityRole="tab"
            accessibilityState={{ selected: focused }}
            accessibilityLabel={route.name === 'deadline' && badge ? `${meta.label}, ${badge} perlu perhatian` : meta.label}
            style={{ flex: 1, alignItems: 'center', gap: 4, minHeight: 48, justifyContent: 'flex-end' }}
          >
            <View>
              <Feather name={meta.icon} size={24} color={color} />
              {route.name === 'deadline' && badge > 0 && (
                <View
                  style={{
                    position: 'absolute',
                    top: -6,
                    right: -12,
                    minWidth: 20,
                    height: 20,
                    paddingHorizontal: 5,
                    borderRadius: radius.pill,
                    backgroundColor: c.category.tugas.solid,
                    borderWidth: 1.5,
                    borderColor: c.line,
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Txt variant="caption" color="#1F1B16" style={{ fontSize: 11, lineHeight: 13 }}>
                    {badge > 9 ? '9+' : badge}
                  </Txt>
                </View>
              )}
            </View>
            <Txt variant="caption" color={color} style={{ fontFamily: focused ? 'PlusJakartaSans_700Bold' : undefined }}>
              {meta.label}
            </Txt>
          </Pressable>
        );
      })}
    </View>
  );
}
