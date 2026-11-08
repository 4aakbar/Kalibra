import { Redirect } from 'expo-router';
import { Tabs } from 'expo-router/js-tabs';

import { TabBar } from '@/components/TabBar';
import { useApp } from '@/lib/store';

export const unstable_settings = { initialRouteName: 'chat' };

export default function TabsLayout() {
  const onboarded = useApp((s) => s.onboarded);
  if (!onboarded) return <Redirect href="/onboarding" />;
  return (
    <Tabs tabBar={(props) => <TabBar {...props} />} screenOptions={{ headerShown: false }}>
      <Tabs.Screen name="kalender" options={{ title: 'Kalender' }} />
      <Tabs.Screen name="chat" options={{ title: 'Chat' }} />
      <Tabs.Screen name="deadline" options={{ title: 'Deadline' }} />
    </Tabs>
  );
}
