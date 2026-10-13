import { router } from 'expo-router';
import type { AppNotification } from '@/api/types';

/** Deep-link map from the prototype: each notification opens one destination, or a fallback if it's gone. */
export function openDestination(n: Pick<AppNotification, 'destination'>) {
  const { kind, id, mode, reason } = n.destination;
  switch (kind) {
    case 'PLAN':
      router.push({ pathname: '/plan/[id]', params: { id: String(id), from: 'notification', mode: mode ?? '' } });
      break;
    case 'CHAT':
      router.push(`/chat/${id}`);
      break;
    case 'GROUP':
      router.push(`/group/${id}`);
      break;
    case 'REQUEST':
      router.push(`/request/${id}`);
      break;
    case 'PROFILE':
      router.push(`/user/${id}`);
      break;
    case 'REPORT':
      router.push(`/safety/reports/${id}`);
      break;
    case 'VERIFY':
      router.push('/verify');
      break;
    case 'SECURITY':
      router.push('/settings/secActivity');
      break;
    default:
      router.push({ pathname: '/unavailable', params: { reason: reason ?? 'content' } });
  }
}
