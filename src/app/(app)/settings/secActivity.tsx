import { router } from 'expo-router';
import { useState } from 'react';
import { meApi, type SecurityEvent } from '@/api';
import { Sheet } from '@/components/Sheet';
import { Button, ErrorBlock, Group, Header, KeyValue, Row, Screen, Skeleton, StateBlock, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { relativeTime } from '@/lib/format';
import { tr, useLanguage } from '@/i18n';

export default function SecurityActivity() {
  useLanguage();
  const { data, error, loading, refresh } = useFocusData(() => meApi.securityEvents());
  const [open, setOpen] = useState<SecurityEvent | null>(null);

  return (
    <Screen>
      <Header kicker={tr('SECURITY')} title={tr('Recent security activity')} />
      <T variant="body">{tr('Important changes and sign-ins from the last 30 days.')}</T>
      {loading ? <Skeleton /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : !data?.length ? (
        <StateBlock icon="check" title={tr('No recent activity')} body={tr('Sign-ins and account changes will appear here.')} />
      ) : (
        <Group style={{ marginTop: 16 }}>
          {data.map((e, i) => <Row key={e.id} first={i === 0} icon="clock" label={e.title} sub={`${relativeTime(e.createdAt)}${e.deviceName ? ` · ${e.deviceName}` : ''}`} onPress={() => setOpen(e)} />)}
        </Group>
      )}
      <Sheet visible={!!open} onClose={() => setOpen(null)} label={open?.title}>
        {open ? (
          <>
            <T variant="kicker">{tr('SECURITY ACTIVITY')}</T>
            <T variant="heading" style={{ marginBottom: 12 }}>{open.title}</T>
            <KeyValue rows={[{ k: tr('When'), v: relativeTime(open.createdAt) }, { k: tr('Device'), v: open.deviceName ?? '—' }, { k: tr('Approximate location'), v: open.area ?? '—' }]} />
            <T variant="small" style={{ marginVertical: 12 }}>{tr('We never ask for your code or password in a message, call or notification.')}</T>
            <Button label={tr('This was me')} onPress={() => setOpen(null)} />
            <Button label={tr('This wasn’t me')} kind="secondary" onPress={() => { setOpen(null); router.replace('/settings/sessions'); }} style={{ marginTop: 8 }} />
          </>
        ) : null}
      </Sheet>
    </Screen>
  );
}
