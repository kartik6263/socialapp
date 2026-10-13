import { useState } from 'react';
import { View } from 'react-native';
import { safetyApi, type BlockedUser } from '@/api';
import { ConfirmDialog } from '@/components/Sheet';
import { Avatar, Button, ErrorBlock, Group, Header, Icon, Screen, Skeleton, StateBlock, T } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { firstName, shortDate } from '@/lib/format';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function BlockedPeople() {
  useLanguage();
  const toast = useToast();
  const { data, setData, error, loading, refresh } = useFocusData(() => safetyApi.blocked());
  const [target, setTarget] = useState<BlockedUser | null>(null);

  return (
    <Screen>
      <Header kicker={tr('SAFETY CENTER')} title={tr('Blocked people')} />
      <T variant="body">{tr('Blocked people can’t message you, send connection requests or see your Plans. They aren’t told.')}</T>
      {loading ? <Skeleton rows={2} /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : !data?.length ? (
        <StateBlock icon="lock" tone="neutral" title={tr('No blocked people')} body={tr('People you block will appear here.')} />
      ) : (
        <Group style={{ marginTop: 14 }}>
          {data.map((b, i) => (
            <View key={b.user.id} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, borderTopWidth: i ? 1 : 0, borderTopColor: colors.divider }}>
              <Avatar name={b.user.displayName} id={b.user.id} size={42} />
              <View style={{ flex: 1 }}>
                <T variant="bodyStrong">{b.user.displayName}</T>
                {b.context ? <T variant="small">{b.context}</T> : null}
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                  <Icon name="lock" size={10} color={colors.inkSoft} />
                  <T variant="caption">{tr('Blocked · {date}', { date: shortDate(b.blockedAt) })}</T>
                </View>
              </View>
              <Button label={tr('Unblock')} compact kind="secondary" onPress={() => setTarget(b)} accessibilityLabel={tr('Unblock {displayName}', { displayName: b.user.displayName })} />
            </View>
          ))}
        </Group>
      )}
      <ConfirmDialog
        visible={!!target}
        onClose={() => setTarget(null)}
        title={tr('Unblock {v}?', { v: firstName(target?.user.displayName ?? '') })}
        body={tr('They’ll be able to see your Plans and send requests again, based on your privacy settings. They won’t be told.')}
        okLabel={tr('Unblock')}
        icon="unlock"
        onConfirm={async () => {
          if (!target) return;
          await safetyApi.unblock(target.user.id);
          setData((d) => d?.filter((x) => x.user.id !== target.user.id) ?? d);
          toast(tr('{v} unblocked', { v: firstName(target.user.displayName) }));
        }}
      />
    </Screen>
  );
}
