import { router, useLocalSearchParams } from 'expo-router';
import { Header, Screen, StateBlock, goBack, type IconName } from '@/components/ui';
import { tr, useLanguage } from '@/i18n';

const FALLBACKS: Record<string, { icon: IconName; title: string; body: string; discover: boolean }> = {
  plan: { icon: 'calendar', title: 'This Plan is no longer available', body: 'The creator removed it. Your connections from it are unaffected.', discover: true },
  removedPlan: { icon: 'calendar', title: 'This Plan is no longer available', body: 'It was removed and can’t be opened. Connections you made through it aren’t affected.', discover: true },
  event: { icon: 'calendar', title: 'This event is no longer available', body: 'It was removed and can’t be opened. Connections you made through it aren’t affected.', discover: true },
  account: { icon: 'user', title: 'This account is no longer available', body: 'The person deleted their account, so this conversation can’t be opened.', discover: false },
  restricted: { icon: 'lock', title: 'This account currently has limited access', body: 'You can’t message or connect with this account right now.', discover: false },
  suspended: { icon: 'user', title: 'This account is unavailable', body: 'You can’t view this profile or message this person.', discover: false },
  group: { icon: 'users', title: 'This group is no longer available', body: 'The Plan Group was closed, so its messages can’t be viewed.', discover: false },
  organizer: { icon: 'users', title: 'This organizer is currently unavailable', body: 'Their profile and events can’t be viewed right now.', discover: true },
  content: { icon: 'eye-off', title: 'This content is no longer available', body: 'It was removed and can’t be viewed.', discover: false },
};

export default function Unavailable() {
  useLanguage();
  const { reason } = useLocalSearchParams<{ reason?: string }>();
  const f = FALLBACKS[reason ?? 'content'] ?? FALLBACKS.content;
  return (
    <Screen>
      <Header />
      <StateBlock
        icon={f.icon}
        tone="neutral"
        title={tr(f.title)}
        body={tr(f.body)}
        actions={[
          { label: tr('Back'), onPress: goBack, kind: f.discover ? 'secondary' : 'primary' },
          ...(f.discover ? [{ label: tr('Discover similar Plans'), onPress: () => router.navigate('/') }] : []),
        ]}
      />
    </Screen>
  );
}
