import * as Linking from 'expo-linking';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Image, Pressable, Share, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ApiError, analyticsApi, plansApi, type PlanDetail, type PlanMember } from '@/api';
import { PlanCover } from '@/components/PlanCover';
import { ActionSheet, ConfirmDialog, Sheet, type SheetAction } from '@/components/Sheet';
import { SignalExplainer, TrustSignals } from '@/components/TrustSignals';
import {
  Avatar, Banner, Button, Diff, ErrorBlock, Field, Icon, IconButton, IconTile, Loading, Pill, PlanStatusPill, Screen, StateBlock, T, goBack,
} from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { firstName, planDate, relativeTime, topSignal } from '@/lib/format';
import { openReport } from '@/lib/report';
import { colors, fonts } from '@/theme';
import { categoryLabel } from '@/lib/categories';
import { tr, useLanguage } from '@/i18n';

const ROLE = { CREATOR: 'Creator', ORGANIZER: 'Organizer', PARTICIPANT: 'Participant' } as const;

export default function PlanDetailScreen() {
  useLanguage();
  const { id, from, mode } = useLocalSearchParams<{ id: string; from?: string; mode?: string }>();
  const toast = useToast();
  const { data: plan, setData, error, loading, refresh } = useFocusData(async () => {
    const p = await plansApi.get(Number(id));
    analyticsApi.track('plan_viewed', { official: p.official });
    return p;
  }, [id]);
  const [showParticipants, setShowParticipants] = useState(false);
  const [reminderDismissed, setReminderDismissed] = useState(false);
  const [menu, setMenu] = useState(false);
  const [manage, setManage] = useState(false);
  const [member, setMember] = useState<PlanMember | null>(null);
  const [confirm, setConfirm] = useState<'leave' | 'complete' | 'delete' | 'remove' | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [officialInfo, setOfficialInfo] = useState(false);

  if (loading) return <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper }}><Loading /></SafeAreaView>;
  if (!plan) {
    const gone = error?.status === 404 || error?.status === 410;
    return (
      <Screen>
        <View style={{ height: 56 }} />
        {gone ? (
          <StateBlock icon="calendar" tone="neutral" title={tr('This Plan is no longer available')} body={tr('It was removed and can’t be opened. Connections you made through it aren’t affected.')} actions={[{ label: tr('Back'), kind: 'secondary', onPress: goBack }, { label: tr('Discover similar Plans'), onPress: () => router.navigate('/') }]} />
        ) : error ? <ErrorBlock error={error} onRetry={refresh} /> : null}
      </Screen>
    );
  }

  const official = plan.official;
  /** Whole sentences for Plans vs official events, so each language keeps natural grammar. */
  const pe = (forPlan: string, forEvent: string) => tr(official ? forEvent : forPlan);
  const cancelled = plan.status === 'CANCELLED';
  const completed = plan.status === 'COMPLETED';
  const inactive = cancelled || completed;
  const full = plan.participantCount >= plan.participantLimit;
  const capacity = tr('{participantCount} of {participantLimit} joined', { participantCount: plan.participantCount, participantLimit: plan.participantLimit });
  const reminder = mode === 'reminder' && plan.startAt && !inactive ? reminderCopy(plan) : null;

  const join = async () => {
    setBusy(true);
    try {
      setData(await plansApi.join(plan.id));
      analyticsApi.track('plan_joined');
      toast(tr('You joined {title}', { title: plan.title }));
    } catch (e) {
      toast(e instanceof ApiError ? e.message : tr('Couldn’t join. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  const share = () =>
    Share.share({ message: tr('{title} · {v} · {area}\nhttps://plans.app/p/{id}{v2}', { title: plan.title, v: planDate(plan.startAt, plan.endAt), area: plan.area, id: plan.id, v2: plan.shareCode ? `?c=${plan.shareCode}` : '' }) }).catch(() => undefined);

  const report = () => openReport({ targetType: plan.official ? 'EVENT' : 'PLAN', targetId: plan.id, title: `“${plan.title}”`, sub: `${plan.host.subtitle} · ${plan.host.name}` });

  const manageActions: SheetAction[] = [
    ...(!inactive ? [
      { label: tr('Edit details'), icon: 'edit-2' as const, sub: tr('Participants see exactly what changed'), onPress: () => router.push(`/plan/${plan.id}/edit`) },
      { label: tr('Post an announcement'), icon: 'volume-2' as const, sub: tr('Pinned in the group and sent to everyone'), onPress: () => router.push(`/plan/${plan.id}/announce`) },
    ] : []),
    { label: tr('Participants'), icon: 'users' as const, sub: tr('Remove, report or block'), onPress: () => setShowParticipants(true) },
    ...(!inactive && plan.status !== 'DRAFT' ? [
      { label: pe('Mark Plan as completed', 'Mark event as completed'), icon: 'check' as const, onPress: () => setConfirm('complete') },
      { label: pe('Cancel Plan', 'Cancel event'), icon: 'x' as const, danger: true, sub: tr('Everyone is notified'), onPress: () => setCancelOpen(true) },
    ] : []),
    ...(plan.status === 'DRAFT' ? [{ label: tr('Delete draft'), icon: 'trash-2' as const, danger: true, onPress: () => setConfirm('delete') }] : []),
  ];

  return (
    <Screen padded={false} edges={[]}>
      <View style={styles.hero}>
        <PlanCover plan={plan} iconSize={110} />
        <View style={styles.scrim} />
        <SafeAreaView edges={['top']} style={styles.heroBar}>
          <IconButton name="chevron-left" label={from === 'notification' ? tr('Back to notifications') : tr('Back')} filled onPress={goBack} />
          <IconButton name="more-horizontal" label={tr('More options for this Plan')} filled onPress={() => setMenu(true)} />
        </SafeAreaView>
        <Text style={styles.cat}>{categoryLabel(plan.category).toUpperCase()}</Text>
      </View>

      <View style={styles.body}>
        {from === 'notification' ? (
          <View style={styles.fromNotif}>
            <Icon name="bell" size={12} color={colors.brand} />
            <T variant="small"><Text style={{ fontFamily: fonts.bodyBold }}>{tr('From Notifications')}</Text> · {mode === 'updated' ? tr('changes are highlighted') : mode === 'reminder' ? tr('your reminder') : mode === 'cancelled' ? tr('this Plan was cancelled') : tr('Plan details')}</T>
          </View>
        ) : null}

        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, flex: 1 }}>
            <Icon name="map-pin" size={12} color={colors.brand} />
            <T variant="kicker" numberOfLines={1}>{plan.area.toUpperCase()} {tr('· APPROXIMATE')}</T>
          </View>
          <PlanStatusPill status={plan.status} />
        </View>
        <T variant="display" style={{ fontSize: 28, lineHeight: 32, marginTop: 6 }} accessibilityRole="header">{plan.title}</T>
        {plan.official ? (
          <View style={{ marginTop: 8 }}><Pill label={tr('Official event')} icon="calendar" tone="ok" onPress={() => setOfficialInfo(true)} accessibilityLabel={tr('Official event. Learn what this means')} /></View>
        ) : null}

        {cancelled ? (
          <View style={[styles.section, { backgroundColor: '#faeaea', borderColor: '#efc9c9' }]} accessibilityRole="alert">
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Icon name="x" size={16} color={colors.danger} />
              <T variant="bodyStrong" style={{ color: colors.danger }}>{plan.official ? tr('This event was cancelled') : tr('This Plan was cancelled')}</T>
            </View>
            {plan.cancelReason ? <T variant="small" style={{ marginTop: 6 }}>“{plan.cancelReason}”</T> : null}
            <T variant="small" style={{ marginTop: 4 }}>{tr('The Plan Group is now read-only. Connections you made stay with you.')}</T>
          </View>
        ) : null}

        {plan.latestChange && !inactive && (plan.status === 'UPDATED' || mode === 'updated') ? (
          <View style={[styles.section, { backgroundColor: '#f2f8fb', borderColor: '#cfe2ea' }]} accessibilityLabel={tr('What changed')}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 }}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                <Icon name="bell" size={14} color="#2b5c74" />
                <T variant="bodyStrong" style={{ color: '#2b5c74' }}>{tr('What changed')}</T>
              </View>
              <T variant="caption">{plan.latestChange.by} · {relativeTime(plan.latestChange.at)}</T>
            </View>
            <Diff changes={plan.latestChange.changes} />
          </View>
        ) : null}

        {reminder ? (
          <View style={[styles.section, { backgroundColor: '#f7fbe0', borderColor: '#e3ec9e' }]}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Icon name="clock" size={15} color={colors.ink} />
              <T variant="bodyStrong">{reminder.title}</T>
            </View>
            <T variant="small" style={{ marginTop: 4 }}>{reminder.body}</T>
            <Button label={tr('Reminder settings')} kind="text" compact onPress={() => router.push('/notifications/settings')} style={{ alignSelf: 'flex-start' }} />
          </View>
        ) : null}

        {!plan.owner && !inactive && !reminderDismissed ? (
          <View style={[styles.section, { flexDirection: 'row', gap: 12 }]} accessibilityLabel={tr('Safety reminder')}>
            <IconTile name="shield" />
            <View style={{ flex: 1 }}>
              <T variant="bodyStrong">{tr('Meeting someone new?')}</T>
              <T variant="small" style={{ marginTop: 2 }}>{tr('Keep your first meeting in a public place and avoid sharing private information.')}</T>
              <View style={{ flexDirection: 'row', gap: 8, marginTop: 10 }}>
                <Button label={tr('Got it')} compact onPress={() => setReminderDismissed(true)} />
                <Button label={tr('Safety tips')} compact kind="secondary" onPress={() => router.push('/safety/guidelines')} />
              </View>
            </View>
          </View>
        ) : null}

        <View style={styles.details} accessibilityLabel={tr('Plan details')}>
          <Detail icon="calendar" label={tr('DATE & TIME')} value={planDate(plan.startAt, plan.endAt)} updated={plan.latestChange?.changes.some((c) => c.field === 'startAt') && plan.status === 'UPDATED'} />
          <Detail
            icon="map-pin"
            label={plan.meetingPointHidden ? tr('MEETING POINT · SHARED AFTER JOINING') : tr('MEETING POINT · PUBLIC')}
            value={plan.meetingPointHidden ? tr('{area} · approximate', { area: plan.area }) : plan.meetingPoint ?? plan.area}
            updated={plan.latestChange?.changes.some((c) => c.field === 'meetingPoint') && plan.status === 'UPDATED'}
          />
          <Detail icon="users" label={tr('CAPACITY')} value={capacity} last />
        </View>

        {completed ? (
          <View style={styles.section} accessibilityRole="text">
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Icon name="check" size={15} color={colors.brand} />
              <T variant="bodyStrong">{plan.official ? tr('This event is complete') : tr('This Plan is complete')}</T>
            </View>
            <T variant="small" style={{ marginTop: 4 }}>{tr('The Plan Group is archived and read-only. Connections people made stay with them.')}</T>
            {plan.owner ? <Button label={tr('Create another Plan')} compact onPress={() => router.push({ pathname: '/plan/new', params: { from: String(plan.id) } })} style={{ marginTop: 10, alignSelf: 'flex-start' }} /> : null}
          </View>
        ) : null}

        {plan.description ? <T variant="body" style={{ marginTop: 16, fontSize: 15, lineHeight: 22 }}>{plan.description}</T> : null}

        {plan.schedule.length || plan.bring || plan.eligibility || plan.instructions ? (
          <View style={styles.section} accessibilityLabel={tr('Event information')}>
            {plan.schedule.length ? (
              <>
                <T variant="kicker" style={{ marginBottom: 8 }}>{tr('SCHEDULE')}</T>
                {plan.schedule.map((s, i) => (
                  <View key={i} style={{ flexDirection: 'row', gap: 12, paddingVertical: 5 }}>
                    <Text style={{ fontFamily: fonts.bodyBold, fontSize: 12, color: colors.ink, width: 66 }}>{s.time}</Text>
                    <T variant="small" style={{ flex: 1 }}>{s.what}</T>
                  </View>
                ))}
              </>
            ) : null}
            <T variant="kicker" style={{ marginTop: plan.schedule.length ? 12 : 0, marginBottom: 6 }}>{tr('GOOD TO KNOW')}</T>
            {[[tr('What to bring'), plan.bring], [tr('Who can join'), plan.eligibility], [tr('Instructions'), plan.instructions]].filter(([, v]) => v).map(([k, v]) => (
              <View key={k} style={{ paddingVertical: 4 }}>
                <T variant="caption">{k}</T>
                <T variant="small" style={{ color: colors.ink }}>{v}</T>
              </View>
            ))}
          </View>
        ) : null}

        <View style={styles.section} accessibilityLabel={plan.host.kind === 'ORGANIZER' ? tr('Hosted by') : tr('Created by')}>
          <T variant="kicker" style={{ color: colors.inkSoft }}>{plan.host.kind === 'ORGANIZER' ? tr('HOSTED BY') : tr('CREATED BY')}</T>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginVertical: 10 }}>
            <Avatar name={plan.host.name} photoUrl={plan.host.photoUrl} id={plan.host.id} size={44} />
            <View style={{ flex: 1 }}>
              <T variant="bodyStrong">{plan.owner && plan.host.kind === 'USER' ? tr('You') : plan.host.name}</T>
              <T variant="small">{plan.host.subtitle}</T>
            </View>
            {!(plan.owner && plan.host.kind === 'USER') ? (
              <Button
                label={plan.host.kind === 'ORGANIZER' ? tr('View organizer') : tr('View profile')}
                compact
                kind="secondary"
                onPress={() => router.push(plan.host.kind === 'ORGANIZER' ? `/organizer/${plan.host.id}` : `/user/${plan.host.id}`)}
              />
            ) : null}
          </View>
          <TrustSignals signals={plan.host.signals} name={plan.host.name} />
          {plan.why ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 10 }}>
              <Icon name="star" size={11} color={colors.brand} />
              <T variant="small">{plan.why}</T>
            </View>
          ) : null}
        </View>

        <View style={styles.section}>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
            <T variant="bodyStrong">{tr('Participants')}</T>
            <Button label={showParticipants ? tr('Hide') : tr('Show all')} kind="text" compact onPress={() => setShowParticipants(!showParticipants)} accessibilityLabel={showParticipants ? tr('Hide participants') : tr('Show all participants')} />
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 4 }}>
            {plan.members.slice(0, 5).map((m, i) => (
              <View key={m.user.id} style={{ marginLeft: i ? -8 : 0, borderWidth: 2, borderColor: colors.surface, borderRadius: 20 }}>
                <Avatar name={m.user.displayName} photoUrl={m.user.photoUrl} id={m.user.id} size={32} />
              </View>
            ))}
            <T variant="small" style={{ marginLeft: 10 }}>{capacity}</T>
          </View>
          {showParticipants ? (
            <View style={{ marginTop: 10 }}>
              {plan.members.map((m, i) => {
                const sig = topSignal(m.user.signals);
                return (
                  <View key={m.user.id} style={[styles.member, i > 0 && { borderTopWidth: 1, borderTopColor: colors.divider }]}>
                    <Pressable style={{ flexDirection: 'row', alignItems: 'center', gap: 10, flex: 1 }} onPress={() => !m.me && router.push(`/user/${m.user.id}`)} accessibilityRole="button">
                      <Avatar name={m.user.displayName} photoUrl={m.user.photoUrl} id={m.user.id} size={34} />
                      <View style={{ flex: 1, gap: 2 }}>
                        <T variant="bodyStrong">{m.me ? tr('You') : m.user.displayName}</T>
                        {sig ? <Pill label={sig} icon="check" tone="ok" /> : null}
                      </View>
                    </Pressable>
                    <T variant="caption">{ROLE[m.role]}</T>
                    {!m.me ? <IconButton name="more-horizontal" label={tr('Options for {displayName}', { displayName: m.user.displayName })} onPress={() => setMember(m)} /> : null}
                  </View>
                );
              })}
            </View>
          ) : null}
        </View>

        {plan.registrationMode === 'EXTERNAL' ? (
          <View style={styles.section} accessibilityLabel={tr('Registration')}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Icon name="link" size={14} color={colors.ink} />
              <T variant="bodyStrong">{tr('External registration required')}</T>
            </View>
            <T variant="small" style={{ marginTop: 4 }}>{tr('Join the Plan here, and also register on the organizer’s site. Plans doesn’t sell tickets or take payments.')}</T>
            {plan.registrationUrl && !inactive ? (
              <Button label={tr('Register on organizer’s site ↗')} compact kind="secondary" onPress={() => Linking.openURL(plan.registrationUrl!.startsWith('http') ? plan.registrationUrl! : `https://${plan.registrationUrl}`)} style={{ marginTop: 10, alignSelf: 'flex-start' }} />
            ) : null}
          </View>
        ) : null}

        <View style={{ gap: 8, marginTop: 18 }}>
          {!plan.owner && !inactive ? (
            plan.joined ? (
              <Button label={tr('Joined · Leave Plan')} kind="secondary" icon="check" onPress={() => setConfirm('leave')} />
            ) : (
              <Button label={full ? tr('Full') : pe('Join Plan', 'Join event')} disabled={full} loading={busy} onPress={join} />
            )
          ) : null}
          {plan.owner ? <Button label={pe('Manage Plan', 'Manage event')} icon="settings" kind={plan.status === 'DRAFT' ? 'secondary' : 'primary'} onPress={() => setManage(true)} /> : null}
          {plan.status === 'DRAFT' && plan.owner ? <Button label={tr('Continue editing draft')} onPress={() => router.push({ pathname: '/plan/new', params: { draft: String(plan.id) } })} /> : null}
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Button label={tr('Share')} icon="share-2" kind="secondary" onPress={share} style={{ flex: 1 }} />
            {!plan.owner ? <Button label={tr('Report')} icon="flag" kind="secondary" onPress={report} style={{ flex: 1 }} /> : null}
          </View>
          {plan.groupConversationId && (plan.joined || plan.owner) ? (
            <Button label={inactive ? tr('View Plan Group (read-only)') : tr('Open Plan Group')} icon="users" kind="secondary" onPress={() => router.push(`/group/${plan.groupConversationId}`)} />
          ) : null}
          {cancelled ? <Button label={tr('Find similar Plans')} kind="text" onPress={() => router.navigate('/')} /> : null}
        </View>

        <View style={[styles.section, { marginTop: 18 }]} accessibilityLabel={tr('Safety')}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <Icon name="shield" size={14} color={colors.brand} />
            <T variant="bodyStrong">{tr('Safety')}</T>
          </View>
          {[
            [tr('Safety guidelines'), () => router.push('/safety/guidelines')],
            [tr('What others can see'), () => router.push('/safety/visibility')],
            ...(!plan.owner ? [[pe('Report this Plan', 'Report this event'), report] as const] : []),
          ].map(([label, run]) => (
            <Pressable key={label as string} onPress={run as () => void} style={styles.safetyRow} accessibilityRole="button">
              <T variant="small" style={{ color: colors.ink, flex: 1 }}>{label as string}</T>
              <Icon name="arrow-right" size={13} color={colors.brand} />
            </Pressable>
          ))}
        </View>
      </View>

      <ActionSheet
        visible={menu}
        onClose={() => setMenu(false)}
        title={plan.title}
        sub={`${planDate(plan.startAt, plan.endAt)} · ${plan.area}`}
        actions={[
          { label: tr('Share'), icon: 'share-2', onPress: share },
          ...(plan.owner ? [{ label: pe('Manage Plan', 'Manage event'), icon: 'settings' as const, onPress: () => setManage(true) }] : []),
          ...(!plan.owner ? [{ label: pe('Report Plan', 'Report event'), icon: 'flag' as const, danger: true, sub: tr('Reports are private'), onPress: report }] : []),
        ]}
      />
      <ActionSheet visible={manage} onClose={() => setManage(false)} title={pe('Manage Plan', 'Manage event')} sub={plan.title} actions={manageActions} />
      <ActionSheet
        visible={!!member}
        onClose={() => setMember(null)}
        title={member?.user.displayName ?? ''}
        sub={member ? ROLE[member.role] : null}
        actions={member ? [
          { label: tr('View profile'), icon: 'user', onPress: () => router.push(`/user/${member.user.id}`) },
          { label: tr('Report {v}', { v: firstName(member.user.displayName) }), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: () => openReport({ targetType: 'PARTICIPANT', targetId: member.user.id, title: member.user.displayName, sub: tr('Participant in {title}', { title: plan.title }), personId: member.user.id, personName: firstName(member.user.displayName) }) },
          ...(plan.owner && member.role === 'PARTICIPANT' ? [{ label: tr('Remove from Plan'), icon: 'user-x' as const, danger: true, sub: tr('They’re told privately'), onPress: () => setConfirm('remove') }] : []),
        ] : []}
      />

      <ConfirmDialog visible={confirm === 'leave'} onClose={() => setConfirm(null)} title={tr('Leave this Plan?')} body={tr('You’ll leave the Plan Group too. Connections you made stay with you.')} okLabel={tr('Leave Plan')} okKind="dangerSolid" icon="log-out" tone="bad"
        onConfirm={async () => setData(await plansApi.leave(plan.id))} />
      <ConfirmDialog visible={confirm === 'complete'} onClose={() => setConfirm(null)} title={pe('Mark Plan as completed?', 'Mark event as completed?')} body={tr('The Plan Group becomes read-only. Participants can keep the connections they made.')} okLabel={tr('Mark completed')} icon="check"
        onConfirm={async () => setData(await plansApi.complete(plan.id))} />
      <ConfirmDialog visible={confirm === 'delete'} onClose={() => setConfirm(null)} title={tr('Delete this draft?')} body={tr('Only you can see drafts. This can’t be undone.')} okLabel={tr('Delete draft')} okKind="dangerSolid" icon="trash-2" tone="bad"
        onConfirm={async () => { await plansApi.remove(plan.id); router.replace('/plans'); }} />
      <ConfirmDialog visible={confirm === 'remove'} onClose={() => { setConfirm(null); setMember(null); }} title={tr('Remove from Plan?')} body={tr('They’ll leave the Plan and its group, and be told privately. They can’t rejoin this Plan.')} okLabel={tr('Remove')} okKind="dangerSolid" icon="user-x" tone="bad"
        onConfirm={async () => { if (member) setData(await plansApi.removeParticipant(plan.id, member.user.id)); }} />

      <CancelSheet
        visible={cancelOpen}
        official={official}
        reason={cancelReason}
        setReason={setCancelReason}
        onClose={() => setCancelOpen(false)}
        onConfirm={async () => {
          const updated: PlanDetail = await plansApi.cancel(plan.id, cancelReason.trim());
          setData(updated);
          setCancelOpen(false);
          toast(pe('Plan cancelled. Participants were notified.', 'Event cancelled. Participants were notified.'));
        }}
      />
      <SignalExplainer explain={officialInfo ? { kind: 'signal', signal: 'OFFICIAL' } : null} onClose={() => setOfficialInfo(false)} />
    </Screen>
  );
}

function reminderCopy(plan: PlanDetail) {
  const mins = Math.round((new Date(plan.startAt!).getTime() - Date.now()) / 60000);
  const others = Math.max(0, plan.participantCount - 1);
  const title = mins <= 0 ? tr('Happening now') : mins < 90 ? (mins < 60 ? tr('Starts in {n} min', { n: mins }) : tr('Starts in 1 hour')) : mins < 36 * 60 ? tr('Starts tomorrow') : tr('Starts {date}', { date: planDate(plan.startAt) });
  const where = plan.meetingPoint && !plan.meetingPointHidden ? tr(' Meet at {meetingPoint} — a public place.', { meetingPoint: plan.meetingPoint }) : '';
  return { title, body: tr(others === 1 ? '{date}. 1 other is going.{where}' : '{date}. {others} others are going.{where}', { date: planDate(plan.startAt, plan.endAt), others, where }) };
}

function Detail({ icon, label, value, updated, last }: { icon: 'calendar' | 'map-pin' | 'users'; label: string; value: string; updated?: boolean; last?: boolean }) {
  useLanguage();
  return (
    <View style={[styles.detail, !last && { borderBottomWidth: 1, borderBottomColor: colors.divider }]}>
      <Icon name={icon} size={18} color={colors.brand} />
      <View style={{ flex: 1 }}>
        <Text style={styles.detailLabel}>{label}</Text>
        <Text style={styles.detailValue}>{value}</Text>
      </View>
      {updated ? <Pill label={tr('Updated')} tone="blue" /> : null}
    </View>
  );
}

function CancelSheet({ visible, official, reason, setReason, onClose, onConfirm }: { visible: boolean; official: boolean; reason: string; setReason: (s: string) => void; onClose: () => void; onConfirm: () => Promise<void> }) {
  useLanguage();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  if (!visible) return null;
  return (
    <Sheet visible onClose={onClose} label={tr(official ? 'Cancel this event' : 'Cancel this Plan')}>
      <T variant="heading">{tr(official ? 'Cancel this event?' : 'Cancel this Plan?')}</T>
      <T variant="small" style={{ marginVertical: 8 }}>{tr('Everyone who joined is notified with your reason. The Plan Group becomes read-only.')}</T>
      <Field label={tr('Reason')} value={reason} onChangeText={setReason} placeholder={tr('The ground is unavailable this week.')} maxLength={200} />
      {error ? <Banner icon="alert-circle" tone="bad" title={error} /> : null}
      <View style={{ flexDirection: 'row', gap: 8, marginTop: 8 }}>
        <Button label={tr('Keep')} kind="secondary" onPress={onClose} style={{ flex: 1 }} />
        <Button
          label={tr(official ? 'Cancel event' : 'Cancel Plan')}
          kind="dangerSolid"
          loading={busy}
          disabled={reason.trim().length < 3}
          style={{ flex: 1 }}
          onPress={async () => {
            setBusy(true);
            setError('');
            try { await onConfirm(); } catch (e) { setError(e instanceof ApiError ? e.message : tr('Couldn’t cancel.')); } finally { setBusy(false); }
          }}
        />
      </View>
    </Sheet>
  );
}


const styles = StyleSheet.create({
  hero: { height: 250, backgroundColor: colors.brandDark },
  scrim: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(15,25,23,0.2)' },
  heroBar: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 12, paddingTop: 6 },
  cat: { position: 'absolute', left: 16, bottom: 26, overflow: 'hidden', backgroundColor: 'rgba(15,25,23,0.45)', color: '#fff', borderRadius: 999, paddingHorizontal: 10, paddingVertical: 5, fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 0.8 },
  body: { marginTop: -16, backgroundColor: colors.paper, borderTopLeftRadius: 24, borderTopRightRadius: 24, paddingHorizontal: 16, paddingTop: 18, paddingBottom: 30 },
  fromNotif: { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: colors.brandPale, borderRadius: 12, padding: 9, marginBottom: 12 },
  section: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, padding: 14, marginTop: 14 },
  details: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, marginTop: 14, overflow: 'hidden' },
  detail: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14 },
  detailLabel: { fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: colors.inkSoft },
  detailValue: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink, marginTop: 2 },
  member: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingVertical: 9 },
  safetyRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, borderTopWidth: 1, borderTopColor: colors.divider },
});
