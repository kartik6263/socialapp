import { router } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { ApiError, verificationApi } from '@/api';
import { Button, Header, IconButton, IconTile, Note, Screen, SectionTitle, StateBlock, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

type Step = 'intro' | 'processing' | 'success' | 'failed' | 'unavailable';

const CHECKS = ['A photo of a government ID (Aadhaar, PAN, passport or driving licence)', 'A short selfie video to match your face to the ID', 'That the name and age range match your profile'];

/**
 * Identity verification is run by a licensed IDV provider in a hosted flow; we only ever receive the result.
 * The app opens the provider session, then polls our backend until the provider's webhook lands.
 */
export default function IdentityVerification() {
  useLanguage();
  const { refreshUser } = useAuth();
  const [step, setStep] = useState<Step>('intro');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const poll = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    verificationApi.state().then((s) => {
      if (s.identity.status === 'UNAVAILABLE') setStep('unavailable');
      else if (s.identity.status === 'IN_PROGRESS' || s.identity.status === 'PENDING') startPolling();
      else if (s.identity.status === 'VERIFIED') setStep('success');
    }).catch(() => undefined);
    return () => { if (poll.current) clearInterval(poll.current); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const startPolling = () => {
    setStep('processing');
    if (poll.current) clearInterval(poll.current);
    poll.current = setInterval(async () => {
      try {
        const s = await verificationApi.state();
        if (s.identity.status === 'VERIFIED') { clearInterval(poll.current!); await refreshUser(); setStep('success'); }
        else if (s.identity.status === 'FAILED') { clearInterval(poll.current!); setStep('failed'); }
        else if (s.identity.status === 'UNAVAILABLE') { clearInterval(poll.current!); setStep('unavailable'); }
      } catch {
        // keep polling; the user can leave and will get a notification
      }
    }, 3000);
  };

  const start = async () => {
    setBusy(true);
    setError(null);
    try {
      const session = await verificationApi.startIdentity();
      if (session.providerUrl) await WebBrowser.openAuthSessionAsync(session.providerUrl, 'plans://verify/identity');
      await verificationApi.submitIdentity(session.sessionId);
      startPolling();
    } catch (e) {
      if (e instanceof ApiError && e.code === 'IDV_UNAVAILABLE') setStep('unavailable');
      else setError(e instanceof ApiError ? e.message : tr('Couldn’t start verification. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  const exit = () => router.back();

  return (
    <Screen edges={['top', 'bottom']}>
      <Header title={tr('Identity verification')} center right={<IconButton name="x" label={tr('Exit verification')} onPress={exit} />} />
      {step === 'intro' ? (
        <>
          <IconTile name="shield" size={56} />
          <T variant="display" style={{ marginTop: 14, fontSize: 28 }}>{tr('Verify your identity')}</T>
          <T variant="body" style={{ marginTop: 8 }}>{tr('Verification helps other people understand that your profile represents a real, verified identity.')}</T>
          <SectionTitle title={tr('What we’ll check')} />
          {CHECKS.map((c, i) => (
            <View key={c} style={styles.check}>
              <Text style={styles.n}>{i + 1}</Text>
              <T variant="small" style={{ flex: 1, color: colors.ink }}>{tr(c)}</T>
            </View>
          ))}
          <SectionTitle title={tr('Why it exists')} />
          <T variant="body">{trRich('It adds {signal} to your profile. It doesn’t rank you, and it doesn’t change who can see your Plans.', { signal: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{tr('Identity verified')}</Text> })}</T>
          <View style={{ marginTop: 14 }}>
            <Note icon="lock">{tr('Your ID is checked by our verification partner and used only for this check. People see the result — never your document, ID number or date of birth.')}</Note>
          </View>
          {error ? <T variant="small" style={{ color: colors.danger, marginTop: 10 }}>{error}</T> : null}
          <View style={{ gap: 8, marginTop: 18 }}>
            <Button label={tr('Start verification')} loading={busy} onPress={start} />
            <Button label={tr('Not now')} kind="secondary" onPress={exit} />
          </View>
        </>
      ) : null}
      {step === 'processing' ? (
        <View style={{ alignItems: 'center', paddingVertical: 40 }} accessibilityLiveRegion="polite">
          <ActivityIndicator size="large" color={colors.brand} />
          <T variant="title" style={{ marginTop: 18, textAlign: 'center' }}>{tr('Verification in progress')}</T>
          <T variant="body" style={{ textAlign: 'center', marginTop: 8 }}>{tr('This usually takes a few minutes — you can leave this screen and we’ll notify you.')}</T>
          <Button label={tr('Back to Verification')} kind="secondary" onPress={exit} style={{ marginTop: 20, alignSelf: 'stretch' }} />
        </View>
      ) : null}
      {step === 'success' ? (
        <StateBlock icon="check" title={tr('Identity verified')} body={tr('Verification completed. Your profile now shows Identity verified. It doesn’t rank you or change who sees your Plans.')}
          actions={[{ label: tr('View my profile'), onPress: () => router.replace('/me') }, { label: tr('Done'), kind: 'secondary', onPress: exit }]} />
      ) : null}
      {step === 'failed' ? (
        <StateBlock icon="refresh-cw" tone="bad" title={tr('Verification couldn’t be completed')} body={tr('The photos couldn’t be matched — glare or blur is the usual cause. Nothing from this attempt appears on your profile.')}
          actions={[{ label: tr('Try again'), onPress: () => setStep('intro') }, { label: tr('Exit'), kind: 'secondary', onPress: exit }]} />
      ) : null}
      {step === 'unavailable' ? (
        <StateBlock icon="clock" tone="neutral" title={tr('Verification isn’t currently available')} body={tr('Identity verification is temporarily unavailable. Your profile works normally without it — you can try again later.')}
          actions={[{ label: tr('Back to Verification'), onPress: exit }]} />
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  check: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8 },
  n: { width: 24, height: 24, borderRadius: 12, backgroundColor: colors.brandPale, color: colors.brand, textAlign: 'center', lineHeight: 24, fontFamily: fonts.bodyBold, fontSize: 12, overflow: 'hidden' },
});
