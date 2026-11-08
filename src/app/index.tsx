import { Redirect } from 'expo-router';

import { useApp } from '@/lib/store';

export default function Index() {
  const onboarded = useApp((s) => s.onboarded);
  return <Redirect href={onboarded ? '/chat' : '/onboarding'} />;
}
