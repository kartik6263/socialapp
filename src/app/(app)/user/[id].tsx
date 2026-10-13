import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { ApiError, analyticsApi, chatApi, connectionsApi, safetyApi, usersApi } from '@/api';
import { ContextRow, SharedPlanCard } from '@/components/ProfileBits';
import { ActionSheet, ConfirmDialog, type SheetAction } from '@/components/Sheet';
import { TrustSignals } from '@/components/TrustSignals';
import { Banner, Button, Chip, ErrorBlock, Header, Icon, IconButton, Loading, Pill, Screen, SectionTitle, StateBlock, T, UserAvatar, goBack } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { intentKicker } from '@/lib/format';
import { openReport } from '@/lib/report';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function PersonProfile() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const toast = useToast();
  const { data: p, setData, error, loading, refresh } = useFocusData(async () => {
    const profile = await usersApi.get(Number(id));
    analyticsApi.track('profile_viewed');
    return profile;
  }, [id]);
  const [menu, setMenu] = useState(false);
  const [confirm, setConfirm] = useState<'block' | 'unblock' | 'remove' | 'cancel' | null>(null);
  const [busy, setBusy] = useState(false);

  if (loading) return <Screen><Header title={tr('Profile')} center /><Loading /></Screen>;
  if (!p) return <Screen><Header title={tr('Profile')} center />{error ? <ErrorBlock error={error} onRetry={refresh} /> : null}</Screen>;

  if (p.availability !== 'AVAILABLE') {
    const map = {
      RESTRICTED: [tr('This account currently has limited access'), tr('You can’t message or connect with this account right now.')],
      SUSPENDED: [tr('This account is unavailable'), tr('You can’t view this profile or message this person.')],
      DELETED: [tr('This account is no longer available'), tr('The person deleted their account.')],
    } as const;
    const [title, body] = map[p.availability];
    return <Screen><Header title={tr('Profile')} center /><StateBlock icon="user" tone="neutral" title={title} body={body} actions={[{ label: tr('Back'), onPress: goBack }]} /></Screen>;
  }

  const connect = async () => {
    setBusy(true);
    try {
      await connectionsApi.send(p.id, p.sharedPlan?.id);
      setData({ ...p, connectionStatus: 'PENDING_OUTGOING' });
      analyticsApi.track('connection_sent', { hasPlan: !!p.sharedPlan });
      toast(tr('Request sent to {firstName}', { firstName: p.firstName }));
    } catch (e) {
      toast(e instanceof ApiError ? e.message : tr('Couldn’t send the request.'));
    } finally {
      setBusy(false);
    }
  };

  const message = async () => {
    try {
      const c = await chatApi.openDirect(p.id);
      router.push(`/chat/${c.id}`);
    } catch (e) {
      toast(e instanceof ApiError ? e.message : tr('Couldn’t open the conversation.'));
    }
  };

  const actions: SheetAction[] = [
    { label: tr('Report {firstName}', { firstName: p.firstName }), icon: 'flag', sub: tr('Reports are private'), danger: true, onPress: () => openReport({ targetType: 'PROFILE', targetId: p.id, title: tr('{displayName}’s profile', { displayName: p.displayName }), sub: p.sharedPlan?.title, personId: p.id, personName: p.firstName }) },
    p.blockedByMe
      ? { label: tr('Unblock {firstName}', { firstName: p.firstName }), icon: 'unlock', onPress: () => setConfirm('unblock') }
      : { label: tr('Block {firstName}', { firstName: p.firstName }), icon: 'slash', sub: tr('They won’t be told'), danger: true, onPress: () => setConfirm('block') },
    ...(p.connectionStatus === 'ACCEPTED' ? [{ label: tr('Remove connection'), icon: 'user-x' as const, onPress: () => setConfirm('remove') }] : []),
    ...(p.connectionStatus === 'PENDING_OUTGOING' ? [{ label: tr('Cancel request'), icon: 'x' as const, onPress: () => setConfirm('cancel') }] : []),
  ];

  const statusLabel = { ACCEPTED: tr('Connected'), PENDING_OUTGOING: tr('Request sent'), PENDING_INCOMING: tr('Wants to connect'), NONE: tr('Not connected'), BLOCKED: tr('Blocked') }[p.connectionStatus];

  return (
    <Screen>
      <Header title={tr('Profile')} center right={<IconButton name="more-horizontal" label={tr('More options for {firstName}', { firstName: p.firstName })} onPress={() => setMenu(true)} />} />
      <View style={styles.hero}>
        <UserAvatar user={p} size={84} />
        {p.intents.length ? <T variant="kicker" style={{ marginTop: 12 }}>{intentKicker(p.intents)}</T> : null}
        <T variant="title" style={{ marginTop: 4 }}>{p.displayName}{p.ageRange ? `, ${p.ageRange}` : ''}</T>
        {p.area ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4 }}>
            <Icon name="map-pin" size={12} color={colors.inkSoft} />
            <T variant="small">{p.area} {tr('· approximate')}</T>
          </View>
        ) : null}
        <View style={{ marginVertical: 10 }}><Pill label={statusLabel} icon="users" /></View>
        <TrustSignals signals={p.signals} name={p.firstName} unavailable={p.signalsUnavailable} />
        {!p.signals.length && !p.signalsUnavailable ? (
          <T variant="small" style={{ textAlign: 'center', marginTop: 8 }}>{tr('No additional trust signals. That’s common for newer members — the profile works normally.')}</T>
        ) : null}
      </View>

      {p.blockedByMe ? (
        <View style={styles.blocked}>
          <Icon name="lock" size={20} color={colors.inkSoft} />
          <T variant="bodyStrong" style={{ marginTop: 8 }}>{tr('You blocked this person')}</T>
          <T variant="small" style={{ textAlign: 'center', marginTop: 4 }}>{tr('They can’t message you, send connection requests or see your Plans. They weren’t told.')}</T>
          <View style={{ flexDirection: 'row', gap: 8, marginTop: 12, alignSelf: 'stretch' }}>
            <Button label={tr('Back')} kind="secondary" onPress={goBack} style={{ flex: 1 }} />
            <Button label={tr('Unblock')} onPress={() => setConfirm('unblock')} style={{ flex: 1 }} />
          </View>
        </View>
      ) : (
        <>
          {p.sharedPlan || p.sharedInterests.length || p.mutualConnections.length ? (
            <View style={styles.common}>
              <T variant="kicker" style={{ color: colors.inkSoft, marginBottom: 8 }}>{tr('YOU HAVE SOMETHING IN COMMON')}</T>
              {p.sharedPlan ? <SharedPlanCard plan={p.sharedPlan} icon="link" onPress={() => router.push(`/plan/${p.sharedPlan!.id}`)} /> : null}
              {p.sharedInterests.length ? <ContextRow icon="star" label={tr('SHARED INTERESTS')} value={p.sharedInterests.join(' · ')} /> : null}
              {p.mutualConnections.length ? <ContextRow icon="users" label={tr('MUTUAL CONNECTIONS')} value={p.mutualConnections.join(', ')} /> : null}
            </View>
          ) : null}

          <SectionTitle title={tr('About')} />
          <T variant="body">{p.bio || tr('{firstName} hasn’t added a bio yet.', { firstName: p.firstName })}</T>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
            {p.interests.map((i) => <Chip key={i} label={i} />)}
          </View>

          <View style={{ marginTop: 22, gap: 8 }}>
            {p.connectionStatus === 'PENDING_INCOMING' && p.connectionId ? (
              <Button label={tr('Respond to request')} onPress={() => router.push(`/request/${p.connectionId}`)} />
            ) : null}
            {p.canMessage ? <Button label={tr('Message {firstName}', { firstName: p.firstName })} icon="message-circle" onPress={message} /> : null}
            {p.canConnect || p.connectionStatus === 'PENDING_OUTGOING' ? (
              <Button
                label={p.connectionStatus === 'PENDING_OUTGOING' ? tr('Request sent') : tr('Connect with {firstName}', { firstName: p.firstName })}
                icon="users"
                kind={p.canMessage ? 'secondary' : 'primary'}
                loading={busy}
                disabled={p.connectionStatus === 'PENDING_OUTGOING'}
                onPress={connect}
              />
            ) : null}
            {!p.canMessage && !p.canConnect && p.connectionStatus === 'NONE' ? (
              <Banner icon="lock" tone="neutral" title={tr('{firstName} isn’t accepting requests right now', { firstName: p.firstName })} body={tr('Their contact settings limit who can connect. You can still join the same Plans.')} />
            ) : null}
          </View>
        </>
      )}

      <ActionSheet visible={menu} onClose={() => setMenu(false)} title={p.displayName} sub={p.sharedPlan ? tr('Met through {title}', { title: p.sharedPlan.title }) : undefined} actions={actions} />
      <ConfirmDialog
        visible={confirm === 'block'}
        onClose={() => setConfirm(null)}
        title={tr('Block {firstName}?', { firstName: p.firstName })}
        body={tr('{firstName} won’t be able to message you, send requests or see your Plans. They won’t be told. You can unblock any time in Safety Center.', { firstName: p.firstName })}
        okLabel={tr('Block')}
        okKind="dangerSolid"
        icon="slash"
        tone="bad"
        onConfirm={async () => {
          await safetyApi.block(p.id);
          setData({ ...p, blockedByMe: true, canMessage: false, canConnect: false, connectionStatus: 'BLOCKED' });
          toast(tr('{firstName} blocked', { firstName: p.firstName }));
        }}
      />
      <ConfirmDialog
        visible={confirm === 'unblock'}
        onClose={() => setConfirm(null)}
        title={tr('Unblock {firstName}?', { firstName: p.firstName })}
        body={tr('They’ll be able to see your Plans and send requests again, based on your privacy settings. They won’t be told.')}
        okLabel={tr('Unblock')}
        icon="unlock"
        onConfirm={async () => {
          await safetyApi.unblock(p.id);
          await refresh();
          toast(tr('{firstName} unblocked', { firstName: p.firstName }));
        }}
      />
      <ConfirmDialog
        visible={confirm === 'remove'}
        onClose={() => setConfirm(null)}
        title={tr('Remove connection?')}
        body={tr('You and {firstName} won’t be connected anymore. They won’t be told why.', { firstName: p.firstName })}
        okLabel={tr('Remove')}
        okKind="dangerSolid"
        icon="user-x"
        tone="bad"
        onConfirm={async () => {
          await connectionsApi.remove(p.id);
          await refresh();
        }}
      />
      <ConfirmDialog
        visible={confirm === 'cancel'}
        onClose={() => setConfirm(null)}
        title={tr('Cancel request?')}
        body={tr('{firstName} won’t see your request anymore.', { firstName: p.firstName })}
        okLabel={tr('Cancel request')}
        cancelLabel={tr('Keep')}
        icon="x"
        onConfirm={async () => {
          if (p.connectionId) await connectionsApi.cancel(p.connectionId);
          await refresh();
        }}
      />
    </Screen>
  );
}


const styles = StyleSheet.create({
  hero: { alignItems: 'center', paddingVertical: 12 },
  blocked: { alignItems: 'center', backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 20, padding: 18, marginTop: 8 },
  common: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 20, padding: 14, marginTop: 8, gap: 4 },
});
