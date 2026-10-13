import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { organizersApi } from '@/api';
import { PlanRow } from '@/components/PlanCard';
import { ActionSheet } from '@/components/Sheet';
import { TrustSignals } from '@/components/TrustSignals';
import { Avatar, Button, ErrorBlock, FilterPills, Group, Header, Icon, IconButton, Loading, Pill, Row, Screen, SectionTitle, StateBlock, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { openReport } from '@/lib/report';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const TYPE = { INDIVIDUAL: 'INDIVIDUAL ORGANIZER', COMMUNITY: 'COMMUNITY ORGANIZER', ORGANIZATION: 'ORGANIZATION', OFFICIAL: 'OFFICIAL EVENT ORGANIZER' } as const;

export default function OrganizerProfileScreen() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data: o, error, loading, refresh } = useFocusData(() => organizersApi.get(Number(id)), [id]);
  const [menu, setMenu] = useState(false);

  if (loading) return <Screen><Header title={tr('Organizer')} center /><Loading /></Screen>;
  if (!o) return <Screen><Header title={tr('Organizer')} center />{error ? <ErrorBlock error={error} onRetry={refresh} /> : null}</Screen>;

  const report = () => openReport({ targetType: 'ORGANIZER', targetId: o.id, title: o.name, sub: tr(TYPE[o.type]).toLowerCase() });

  return (
    <Screen>
      <Header title={tr('Organizer')} center right={!o.mine ? <IconButton name="more-horizontal" label={tr('More options for this organizer')} onPress={() => setMenu(true)} /> : undefined} />
      {!o.available ? (
        <StateBlock icon="users" tone="neutral" title={tr('This organizer is currently unavailable')} body={tr('Their profile and events can’t be viewed right now.')} />
      ) : (
        <>
          {o.mine ? (
            <View style={{ marginBottom: 12 }}>
              <FilterPills options={[{ key: 'personal', label: tr('Personal profile') }, { key: 'org', label: tr('Organizer profile') }]} value="org" onChange={(k) => k === 'personal' && router.replace('/me')} />
            </View>
          ) : null}
          <View style={{ alignItems: 'center', paddingVertical: 12 }}>
            <Avatar name={o.name} id={o.id} size={80} tone="mint" />
            <T variant="kicker" style={{ marginTop: 12 }}>{tr(TYPE[o.type])}</T>
            <T variant="title" style={{ marginTop: 4, textAlign: 'center' }}>{o.name}</T>
            {o.area ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4, marginBottom: 10 }}>
                <Icon name="map-pin" size={12} color={colors.inkSoft} />
                <T variant="small">{o.area}</T>
              </View>
            ) : null}
            <View style={{ flexDirection: 'row', gap: 6, flexWrap: 'wrap', justifyContent: 'center' }}>
              <TrustSignals signals={o.signals} name={o.name} />
              {o.status !== 'VERIFIED' ? <Pill label={o.status === 'IN_REVIEW' || o.status === 'SUBMITTED' ? tr('In review') : tr('Not verified')} tone="neutral" /> : null}
            </View>
          </View>
          {o.about ? <T variant="body" style={{ marginVertical: 8 }}>{o.about}</T> : null}
          <Group style={{ marginTop: 8 }}>
            {o.website ? <Row first icon="globe" label={tr('Website')} value={o.website} /> : null}
            <Row first={!o.website} icon="message-circle" label={tr('Contact')} sub={tr('Through Plan Groups — no private contact shown')} />
            <Row icon="calendar" label={tr('Organizing since')} value={o.since} />
          </Group>

          <SectionTitle title={tr('Upcoming')} />
          {o.upcoming.length ? (
            <Group>{o.upcoming.map((p, i) => <PlanRow key={p.id} plan={p} first={i === 0} onPress={() => router.push(`/plan/${p.id}`)} />)}</Group>
          ) : <T variant="small">{tr('No upcoming Plans right now.')}</T>}
          {o.past.length ? (
            <>
              <SectionTitle title={tr('Past')} />
              <Group>{o.past.map((p, i) => <PlanRow key={p.id} plan={p} first={i === 0} onPress={() => router.push(`/plan/${p.id}`)} />)}</Group>
            </>
          ) : null}
          <T variant="small" style={{ marginTop: 16 }}>{tr('Organizer verification confirms the organisation. It doesn’t guarantee the quality, safety or outcome of an event. No follower counts or ratings are shown.')}</T>
          {o.mine ? (
            <Button label={tr('Create an event')} icon="plus" onPress={() => router.push('/plan/new')} style={{ marginTop: 16 }} />
          ) : (
            <Button label={tr('Report this organizer')} icon="flag" kind="secondary" onPress={report} style={{ marginTop: 16 }} />
          )}
        </>
      )}
      <ActionSheet visible={menu} onClose={() => setMenu(false)} title={o.name} actions={[{ label: tr('Report this organizer'), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: report }]} />
    </Screen>
  );
}
