import * as Notifications from 'expo-notifications';
import { Stack } from 'expo-router';
import { useEffect } from 'react';
import type { DestinationKind } from '@/api/types';
import { PrivacyChoices } from '@/components/PrivacyChoices';
import { openDestination } from '@/lib/destination';
import { enablePush, getPushPermission } from '@/lib/push';
import { colors } from '@/theme';

Notifications.setNotificationHandler({
  handleNotification: async () => ({ shouldShowBanner: true, shouldShowList: true, shouldPlaySound: false, shouldSetBadge: false }),
});

/** Opens the screen a push points to, using the same deep-link map as the in-app list. */
function openFromPush(response: Notifications.NotificationResponse | null) {
  const data = response?.notification.request.content.data as { kind?: DestinationKind; id?: string; mode?: string } | undefined;
  if (!data?.kind) return;
  openDestination({ destination: { kind: data.kind, id: data.id ? Number(data.id) : null, mode: data.mode || null } });
}

export default function AppLayout() {
  useEffect(() => {
    // Refresh the device token on every launch once permission exists (tokens rotate).
    void getPushPermission().then((p) => {
      if (p === 'granted') void enablePush();
    });
    void Notifications.getLastNotificationResponseAsync().then(openFromPush);
    const sub = Notifications.addNotificationResponseReceivedListener(openFromPush);
    return () => sub.remove();
  }, []);

  return (
    <>
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.paper } }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="plan/new" options={{ presentation: 'modal' }} />
      <Stack.Screen name="report" options={{ presentation: 'modal' }} />
    </Stack>
    <PrivacyChoices />
    </>
  );
}
