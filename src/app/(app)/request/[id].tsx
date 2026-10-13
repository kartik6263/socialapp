import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { ApiError, analyticsApi, chatApi, connectionsApi } from '@/api';
import { ContextRow, SharedPlanCard } from '@/components/ProfileBits';
import { SignalExplainer, TrustSignals } from '@/components/TrustSignals';
import { Banner, Button, ErrorBlock, Header, Icon, Loading, Screen, T, UserAvatar } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { firstName, intentKicker, relativeTime } from '@/lib/format';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function ConnectionRequestScreen() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data: req, setData, error, loading, refresh } = useFocusData(() => connectionsApi.request(Number(id)), [id]);
  const [busy, setBusy] = useState<'accept' | 'decline' | null>(null);
  const [actionError, setActionError] = useState('');
  const [about, setAbout] = useState(false);

  if (loading) return <Screen><Header title={tr('Connection request')} center /><Loading /></Screen>;
  if (!req) return <Screen><Header title={tr('Connection request')} center />{error ? <ErrorBlock error={error} onRetry={refresh} /> : null}</Screen>;

  const name = firstName(req.from.displayName);
  const act = async (kind: 'accept' | 'decline') => {
    setBusy(kind);
    setActionError('');
    try {
      setData(kind === 'accept' ? await connectionsApi.accept(req.id) : await connectionsApi.decline(req.id));
      if (kind === 'accept') analyticsApi.track('connection_accepted');
    } catch (e) {
      setActionError(e instanceof ApiError ? e.message : tr('Something went wrong. Try again.'));
    } finally {
      setBusy(null);
    }
  };

  const message = async () => {
    const c = await chatApi.openDirect(req.from.id);
    router.replace(`/chat/${c.id}`);
  };

  return (
    <Screen>
      <Header title={tr('Connection request')} center />
      <View style={styles.hero}>
        <UserAvatar user={req.from} size={76} />
        {req.intents.length ? <T variant="kicker" style={{ marginTop: 12 }}>{intentKicker(req.intents)}</T> : null}
        <T variant="title" style={{ marginTop: 4 }}>{req.from.displayName}{req.ageRange ? `, ${req.ageRange}` : ''}</T>
        {req.from.area ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4, marginBottom: 10 }}>
            <Icon name="map-pin" size={12} color={colors.inkSoft} />
            <T variant="small">{req.from.area} {tr('· approximate')}</T>
          </View>
        ) : null}
        <TrustSignals signals={req.from.signals} name={name} unavailable={req.from.signalsUnavailable} />
      </View>

      <View style={{ gap: 10 }}>
        {req.sharedPlan ? <SharedPlanCard plan={req.sharedPlan} onPress={() => router.push(`/plan/${req.sharedPlan!.id}`)} /> : null}
        {req.sharedInterests.length ? <ContextRow icon="star" label={tr('SHARED INTERESTS')} value={req.sharedInterests.join(' · ')} /> : null}
        <Button label={tr('What do these signals mean? You decide — we don’t recommend.')} kind="text" icon="shield" compact onPress={() => setAbout(true)} />
        {req.note ? (
          <View style={styles.note}>
            <T variant="kicker" style={{ color: colors.inkSoft }}>{tr('{name}’s note · {when}', { name, when: relativeTime(req.createdAt) }).toUpperCase()}</T>
            <T variant="body" style={{ marginTop: 6, color: colors.ink }}>“{req.note}”</T>
          </View>
        ) : null}
      </View>

      {actionError ? <View style={{ marginTop: 12 }}><Banner icon="alert-circle" tone="bad" title={actionError} /></View> : null}

      {req.status === 'PENDING' ? (
        <>
          <View style={{ flexDirection: 'row', gap: 8, marginTop: 18 }}>
            <Button label={tr('Decline')} kind="secondary" loading={busy === 'decline'} disabled={!!busy} onPress={() => act('decline')} style={{ flex: 1 }} />
            <Button label={busy === 'accept' ? tr('Connecting…') : tr('Accept')} loading={busy === 'accept'} disabled={!!busy} onPress={() => act('accept')} style={{ flex: 1 }} />
          </View>
          <T variant="small" style={{ textAlign: 'center', marginTop: 8 }}>{name} {tr('won’t be told if you decline.')}</T>
          <Button label={tr('View full profile')} kind="text" iconRight="arrow-right" onPress={() => router.push(`/user/${req.from.id}`)} />
        </>
      ) : req.status === 'ACCEPTED' ? (
        <View style={styles.done}>
          <Banner icon="check" title={tr('You’re connected')} body={req.sharedPlan ? tr('Connected through {title}', { title: req.sharedPlan.title }) : undefined} />
          <View style={{ flexDirection: 'row', gap: 8, marginTop: 10 }}>
            <Button label={tr('View profile')} kind="secondary" onPress={() => router.push(`/user/${req.from.id}`)} style={{ flex: 1 }} />
            <Button label={tr('Message')} onPress={message} style={{ flex: 1 }} />
          </View>
        </View>
      ) : (
        <View style={styles.done}>
          <Banner icon="info" tone="neutral" title={tr('Request declined.')} body={tr('You can still both join the Plan — nothing else changes.')} />
        </View>
      )}
      <SignalExplainer explain={about ? { kind: 'about' } : null} onClose={() => setAbout(false)} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { alignItems: 'center', paddingVertical: 12, marginBottom: 6 },
  note: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, padding: 14 },
  done: { marginTop: 18 },
});
