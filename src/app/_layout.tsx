import {
  BricolageGrotesque_700Bold,
  BricolageGrotesque_800ExtraBold,
} from '@expo-google-fonts/bricolage-grotesque';
import {
  PlusJakartaSans_400Regular,
  PlusJakartaSans_500Medium,
  PlusJakartaSans_600SemiBold,
  PlusJakartaSans_700Bold,
} from '@expo-google-fonts/plus-jakarta-sans';
import { useFonts } from 'expo-font';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { ToastHost } from '@/components/Toast';
import { configureNotifications, listenToResponses, scheduleSync } from '@/lib/notifications';
import { useApp } from '@/lib/store';
import { useTheme } from '@/theme';

SplashScreen.preventAutoHideAsync().catch(() => undefined);

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    BricolageGrotesque_700Bold,
    BricolageGrotesque_800ExtraBold,
    PlusJakartaSans_400Regular,
    PlusJakartaSans_500Medium,
    PlusJakartaSans_600SemiBold,
    PlusJakartaSans_700Bold,
  });
  const hydrated = useApp((s) => s.hydrated);
  const c = useTheme();
  const ready = (fontsLoaded || !!fontError) && hydrated;

  useEffect(() => {
    if (ready) SplashScreen.hideAsync().catch(() => undefined);
  }, [ready]);

  useEffect(() => {
    configureNotifications().catch(() => undefined);
    const unlisten = listenToResponses();
    // Jadwalkan ulang pengingat setiap kali jadwal atau preferensi berubah.
    const unsub = useApp.subscribe((state, prev) => {
      if (state.schedules !== prev.schedules || state.prefs !== prev.prefs) scheduleSync();
    });
    scheduleSync();
    return () => {
      unlisten();
      unsub();
    };
  }, []);

  if (!ready) return <View style={{ flex: 1, backgroundColor: c.bg }} />;

  const navTheme = c.scheme === 'dark' ? DarkTheme : DefaultTheme;
  return (
    <SafeAreaProvider>
      <ThemeProvider
        value={{
          ...navTheme,
          colors: { ...navTheme.colors, background: c.bg, card: c.bg, text: c.ink, primary: c.primary, border: c.line },
        }}
      >
        <StatusBar style={c.scheme === 'dark' ? 'light' : 'dark'} />
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.bg } }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="onboarding" options={{ gestureEnabled: false }} />
          <Stack.Screen name="jadwal/form" options={{ presentation: 'modal' }} />
        </Stack>
        <ToastHost />
      </ThemeProvider>
    </SafeAreaProvider>
  );
}
