import { View } from 'react-native';
import { Banner } from './ui';
import { tr, useLanguage } from '@/i18n';

export function SaveErrorBanner({ error }: { error: { offline: boolean; retry: () => void } | null }) {
  useLanguage();
  if (!error) return null;
  return (
    <View style={{ marginBottom: 12 }}>
      <Banner
        icon={error.offline ? 'wifi-off' : 'refresh-cw'}
        tone="bad"
        title={error.offline ? tr('You’re offline') : tr('We couldn’t save this change')}
        body={error.offline ? tr('Reconnect to save this change. Nothing was changed.') : tr('Your setting wasn’t changed. Try again.')}
        action={error.offline ? tr('Retry') : tr('Try again')}
        onAction={error.retry}
      />
    </View>
  );
}
