import { router } from 'expo-router';
import { useState } from 'react';
import { Text, View } from 'react-native';
import { ApiError, verificationApi } from '@/api';
import { Button, ErrorBlock, Field, Header, IconTile, Loading, Pill, Screen, StateBlock, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { useFocusData } from '@/hooks/useAsync';
import { colors, fonts } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

export default function EmailVerification() {
  useLanguage();
  const { refreshUser } = useAuth();
  const { data: v, setData, error, loading, refresh } = useFocusData(async () => {
    const s = await verificationApi.state();
    if (s.email.status === 'VERIFIED') void refreshUser();
    return s;
  });
  const [changing, setChanging] = useState(false);
  const [draft, setDraft] = useState('');
  const [sent, setSent] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (loading) return <Screen><Header kicker={tr('VERIFICATION')} title={tr('Email')} /><Loading /></Screen>;
  if (!v) return <Screen><Header kicker={tr('VERIFICATION')} title={tr('Email')} />{error ? <ErrorBlock error={error} onRetry={refresh} /> : null}</Screen>;

  const sendLink = async (email?: string) => {
    if (email !== undefined && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return setErr(tr('Enter a valid email address.'));
    setBusy(true);
    setErr(null);
    try {
      setData(await verificationApi.sendEmailLink(email?.trim()));
      setSent(true);
      setChanging(false);
    } catch (e) {
      setErr(e instanceof ApiError ? e.message : tr('Couldn’t send the link.'));
    } finally {
      setBusy(false);
    }
  };

  if (v.email.status === 'VERIFIED') {
    return (
      <Screen>
        <Header kicker={tr('VERIFICATION')} title={tr('Email')} />
        <StateBlock icon="check" title={tr('Email verified')} body={tr('Your address stays private. Other people only see Email verified on your profile.')} actions={[{ label: tr('Done'), onPress: () => router.back() }]} />
      </Screen>
    );
  }

  return (
    <Screen edges={['top', 'bottom']}>
      <Header kicker={tr('VERIFICATION')} title={tr('Email')} />
      {changing || !v.email.masked ? (
        <>
          <T variant="title">{v.email.masked ? tr('Change email') : tr('Add your email')}</T>
          <T variant="body" style={{ marginVertical: 8 }}>{tr('We’ll send a verification link. Your address is never shown to other people.')}</T>
          <Field label={tr('Email address')} value={draft} onChangeText={setDraft} keyboardType="email-address" autoCapitalize="none" autoComplete="email" placeholder={tr('name@example.com')} error={err} />
          <Button label={tr('Send verification link')} loading={busy} onPress={() => sendLink(draft)} />
          {v.email.masked ? <Button label={tr('Cancel')} kind="text" onPress={() => setChanging(false)} /> : null}
        </>
      ) : (
        <>
          <IconTile name="message-circle" size={52} />
          <T variant="title" style={{ marginTop: 14 }}>{tr('Verify your email')}</T>
          <T variant="body" style={{ marginVertical: 8 }}>
            {trRich('We sent a verification link to {email}. Open it on any device to finish.', { email: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{v.email.masked}</Text> })}
          </T>
          <Pill label={tr('Verification pending')} tone="blue" icon="clock" />
          {err ? <T variant="small" style={{ color: colors.danger, marginTop: 8 }}>{err}</T> : null}
          <View style={{ gap: 8, marginTop: 18 }}>
            <Button label={sent ? tr('Sent again — check your inbox') : tr('Resend verification email')} kind="secondary" disabled={sent} loading={busy} onPress={() => sendLink()} />
            <Button label={tr('Change email')} kind="text" onPress={() => setChanging(true)} />
            <Button label={tr('I’ve opened the link')} onPress={refresh} />
          </View>
        </>
      )}
    </Screen>
  );
}
