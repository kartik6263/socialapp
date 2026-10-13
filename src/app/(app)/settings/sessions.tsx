import { useState } from 'react';
import { meApi, type Session } from '@/api';
import { ActionSheet, ConfirmDialog } from '@/components/Sheet';
import { Button, ErrorBlock, Group, Header, Row, Screen, SectionTitle, Skeleton, T } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { relativeTime } from '@/lib/format';
import { tr, useLanguage } from '@/i18n';

const icon = (s: Session) => (s.platform === 'WEB' ? 'monitor' : 'smartphone') as 'monitor' | 'smartphone';

export default function Sessions() {
  useLanguage();
  const toast = useToast();
  const { data, setData, error, loading, refresh } = useFocusData(() => meApi.sessions());
  const [sheet, setSheet] = useState<Session | null>(null);
  const [confirm, setConfirm] = useState<{ kind: 'one'; s: Session } | { kind: 'others' } | null>(null);

  const current = data?.filter((s) => s.current) ?? [];
  const others = data?.filter((s) => !s.current) ?? [];

  return (
    <Screen>
      <Header kicker={tr('SECURITY')} title={tr('Active sessions')} />
      <T variant="body">{tr('Where you’re signed in. Locations are approximate, based on the network.')}</T>
      {loading ? <Skeleton /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : (
        <>
          <SectionTitle title={tr('This device')} />
          <Group>{current.map((s, i) => <Row key={s.id} first={i === 0} icon={icon(s)} label={s.deviceName} sub={`${s.app}${s.area ? ` · ${s.area}` : ''}`} value={tr('Active now')} tag={tr('Current session')} tagTone="ok" />)}</Group>
          {others.length ? (
            <>
              <SectionTitle title={tr('Other devices')} />
              <Group>{others.map((s, i) => <Row key={s.id} first={i === 0} icon={icon(s)} label={s.deviceName} sub={`${s.app}${s.area ? ` · ${s.area}` : ''} · ${relativeTime(s.lastActiveAt)}`} onPress={() => setSheet(s)} />)}</Group>
              <Button label={tr('Sign out all other devices')} kind="secondary" onPress={() => setConfirm({ kind: 'others' })} style={{ marginTop: 16 }} />
            </>
          ) : (
            <Group style={{ marginTop: 16 }}><Row first icon="check" label={tr('No other devices')} sub={tr('You’re only signed in here.')} /></Group>
          )}
        </>
      )}
      <ActionSheet
        visible={!!sheet}
        onClose={() => setSheet(null)}
        title={sheet?.deviceName ?? ''}
        sub={sheet ? `${sheet.app} · ${sheet.area ?? ''} · ${relativeTime(sheet.lastActiveAt)}` : null}
        actions={sheet ? [{ label: tr('Sign out this device'), icon: 'log-out', danger: true, sub: tr('It will need to sign in again'), onPress: () => setConfirm({ kind: 'one', s: sheet }) }] : []}
      />
      <ConfirmDialog
        visible={!!confirm}
        onClose={() => setConfirm(null)}
        title={confirm?.kind === 'one' ? tr('Sign out {deviceName}?', { deviceName: confirm.s.deviceName }) : tr('Sign out other devices?')}
        body={confirm?.kind === 'one' ? tr('That device will need to sign in again.') : tr('You’ll stay signed in on this device.')}
        okLabel={tr('Sign out')}
        icon="smartphone"
        onConfirm={async () => {
          if (confirm?.kind === 'one') {
            await meApi.signOutSession(confirm.s.id);
            setData((d) => d?.filter((x) => x.id !== confirm.s.id) ?? d);
            toast(tr('{deviceName} signed out', { deviceName: confirm.s.deviceName }));
          } else {
            await meApi.signOutOthers();
            setData((d) => d?.filter((x) => x.current) ?? d);
            toast(tr('Other sessions signed out'));
          }
        }}
      />
    </Screen>
  );
}
