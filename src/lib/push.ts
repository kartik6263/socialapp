import * as Device from 'expo-device';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { meApi } from '@/api';
import { tr } from '@/i18n';

export type PushPermission = 'granted' | 'denied' | 'undetermined';

export async function getPushPermission(): Promise<PushPermission> {
  const { status } = await Notifications.getPermissionsAsync();
  return status as PushPermission;
}

/**
 * Asks for OS permission and registers the native FCM/APNs token with our backend.
 * We send through FCM/APNs directly (not a third-party relay) so delivery scales with Google/Apple infra.
 */
export async function enablePush(): Promise<PushPermission> {
  if (!Device.isDevice) return 'denied';
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('default', { name: 'Plans', importance: Notifications.AndroidImportance.DEFAULT });
    await Notifications.setNotificationChannelAsync('important', { name: tr('Important Plan updates'), importance: Notifications.AndroidImportance.HIGH });
  }
  const { status } = await Notifications.requestPermissionsAsync();
  if (status !== 'granted') return status as PushPermission;
  try {
    const token = await Notifications.getDevicePushTokenAsync();
    await meApi.registerPushToken(String(token.data), Platform.OS.toUpperCase());
  } catch {
    // Token registration retries on next launch; permission itself succeeded.
  }
  return 'granted';
}
