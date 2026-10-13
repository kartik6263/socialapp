import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { ApiError, notificationsApi, type NotificationPrefs } from '@/api';
import { Banner, Chip, ErrorBlock, Group, Header, Pill, Row, Screen, SectionTitle, Skeleton, T, ToggleRow } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { enablePush, getPushPermission, type PushPermission } from '@/lib/push';
import { tr, useLanguage } from '@/i18n';

type Key = keyof NotificationPrefs;

const SECTIONS: { title: string; rows: { k: Key; label: string; sub?: string }[]; note?: string; plans?: boolean }[] = [
  { title: 'Messages', rows: [{ k: 'directMessages', label: 'Direct messages', sub: 'Repeat messages are grouped.' }, { k: 'groupMessages', label: 'Group messages', sub: 'Grouped per Plan Group.' }] },
  { title: 'Connections', rows: [{ k: 'connectionRequests', label: 'Connection requests' }, { k: 'acceptedRequests', label: 'Accepted requests' }] },
  {
    title: 'Plans', plans: true,
    rows: [
      { k: 'planUpdates', label: 'Plan updates', sub: 'Time, place or capacity changes.' },
      { k: 'planReminders', label: 'Plan reminders' },
      { k: 'participantUpdates', label: 'Participant updates', sub: 'Joins and leaves on Plans you created.' },
      { k: 'cancellations', label: 'Cancellation & completion' },
    ],
  },
  { title: 'Groups', rows: [{ k: 'announcements', label: 'Important announcements', sub: 'From the Plan creator.' }], note: 'Group messages are under Messages.' },
  { title: 'Discovery', rows: [{ k: 'suggestions', label: 'Relevant Plan suggestions', sub: 'At most one a week. Never promotional.' }] },
];

export default function NotificationSettings() {
  useLanguage();
  const toast = useToast();
  const { data, setData, error, loading, refresh } = useFocusData(() => notificationsApi.prefs());
  const [permission, setPermission] = useState<PushPermission | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    void getPushPermission().then(setPermission);
  }, []);

  const update = async (patch: Partial<NotificationPrefs>) => {
    if (!data) return;
    const previous = data;
    setData({ ...data, ...patch });
    setSaveError(null);
    try {
      setData(await notificationsApi.updatePrefs(patch));
    } catch (e) {
      setData(previous);
      setSaveError(e instanceof ApiError && e.isNetwork ? tr('You’re offline. Reconnect to save this change. Nothing was changed.') : tr('Your setting wasn’t changed. Try again.'));
    }
  };

  return (
    <Screen>
      <Header kicker={tr('SETTINGS')} title={tr('Notifications')} />
      {saveError ? <View style={{ marginBottom: 12 }}><Banner icon="refresh-cw" tone="bad" title={tr('We couldn’t save this change')} body={saveError} /></View> : null}
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <View style={{ flex: 1, backgroundColor: '#fff', borderRadius: 16, padding: 12, borderWidth: 1, borderColor: '#dfe6e1' }}>
          <T variant="bodyStrong">{tr('In-app')}</T>
          <T variant="small">{tr('Always listed in Notifications.')}</T>
        </View>
        <View style={{ flex: 1, backgroundColor: '#fff', borderRadius: 16, padding: 12, borderWidth: 1, borderColor: '#dfe6e1' }}>
          <T variant="bodyStrong">{tr('Push')}</T>
          <T variant="small">{tr('Outside the app, for the categories you choose.')}</T>
        </View>
      </View>

      {permission === 'denied' || permission === 'undetermined' ? (
        <View style={{ marginTop: 12 }}>
          <Banner icon="bell-off" tone="warn" title={tr('Push is off on this device')} body={tr('In-app notifications still appear.')} action={tr('Enable')} onAction={async () => {
            const p = await enablePush();
            setPermission(p);
            if (p !== 'granted') toast(tr('Turn on notifications for Plans in your device settings.'));
          }} />
        </View>
      ) : null}

      {loading ? <Skeleton rows={5} /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : data ? (
        <>
          <Group style={{ marginTop: 12 }}>
            <ToggleRow first label={tr('Push notifications')} sub={data.push ? tr('On for the categories below') : tr('Off — in-app only')} value={data.push} onChange={(v) => update({ push: v })} />
          </Group>
          {SECTIONS.map((s) => (
            <View key={s.title}>
              <SectionTitle title={tr(s.title)} />
              <Group>
                {s.rows.map((r, i) => (
                  <ToggleRow key={r.k} first={i === 0} label={tr(r.label)} sub={r.sub ? tr(r.sub) : undefined} value={data[r.k] as boolean} onChange={(v) => update({ [r.k]: v })} />
                ))}
                {s.plans ? (
                  <View style={{ padding: 14, borderTopWidth: 1, borderTopColor: '#eef1ee', gap: 8 }}>
                    <T variant="bodyStrong">{tr('Remind me')}</T>
                    <T variant="small">{tr('At most two reminders per Plan.')}</T>
                    <View style={{ flexDirection: 'row', gap: 8 }}>
                      <Chip label={tr('Day before')} selected={data.remindDayBefore} onPress={() => update({ remindDayBefore: !data.remindDayBefore })} />
                      <Chip label={tr('1 hour before')} selected={data.remindHourBefore} onPress={() => update({ remindHourBefore: !data.remindHourBefore })} />
                    </View>
                  </View>
                ) : null}
              </Group>
              {s.note ? <T variant="small" style={{ marginTop: 6 }}>{tr(s.note)}</T> : null}
            </View>
          ))}
          <SectionTitle title={tr('Safety & security')} />
          <Group>
            <Row first label={tr('Security alerts')} sub={tr('Sign-ins and account changes.')} right={<Pill label={tr('Always on')} icon="lock" />} />
            <Row label={tr('Safety & account updates')} sub={tr('Report outcomes, restrictions.')} right={<Pill label={tr('Always on')} icon="lock" />} />
          </Group>
          <T variant="small" style={{ marginTop: 6 }}>{tr('These always reach you in-app and by push, so you never miss a change to your account.')}</T>
        </>
      ) : null}
    </Screen>
  );
}
