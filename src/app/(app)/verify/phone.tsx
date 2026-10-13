import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { Text, View } from 'react-native';
import { ApiError, verificationApi } from '@/api';
import { Button, Field, Header, IconTile, Screen, StateBlock, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

type Step = 'enter' | 'locked' | 'verified';

export default function PhoneVerification() {
  useLanguage();
  const me = useMe();
  const { refreshUser } = useAuth();
  const [step, setStep] = useState<Step>('enter');
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [resendIn, setResendIn] = useState(0);
  const [busy, setBusy] = useState(false);
  const [devCode, setDevCode] = useState<string | null>(null);

  const send = async () => {
    setError(null);
    try {
      const r = await verificationApi.sendPhoneCode();
      setResendIn(r.resendInSeconds);
      setDevCode(r.devCode ?? null);
    } catch (e) {
      if (e instanceof ApiError && e.code === 'TOO_MANY_ATTEMPTS') setStep('locked');
      else setError(e instanceof ApiError ? e.message : tr('Couldn’t send a code.'));
    }
  };

  useEffect(() => {
    void send();
  }, []);

  useEffect(() => {
    if (resendIn <= 0) return;
    const t = setInterval(() => setResendIn((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, [resendIn]);

  const verify = async () => {
    setBusy(true);
    setError(null);
    try {
      await verificationApi.verifyPhone(code);
      await refreshUser();
      setStep('verified');
    } catch (e) {
      if (e instanceof ApiError && e.code === 'TOO_MANY_ATTEMPTS') setStep('locked');
      else setError(e instanceof ApiError ? e.message : tr('We couldn’t check your code. Nothing has changed — try again.'));
      setCode('');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Header kicker={tr('VERIFICATION')} title={tr('Phone')} />
      {step === 'enter' ? (
        <>
          <IconTile name="lock" size={52} />
          <T variant="title" style={{ marginTop: 14 }}>{tr('Verify your phone')}</T>
          <T variant="body" style={{ marginVertical: 8 }}>
            {trRich('Enter the 6-digit code we sent to {phone}.', { phone: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{me.maskedPhone ?? tr('your phone')}</Text> })}
          </T>
          <Field label={tr('6-digit verification code')} value={code} onChangeText={(t) => setCode(t.replace(/\D/g, '').slice(0, 6))} keyboardType="number-pad" textContentType="oneTimeCode" autoComplete="sms-otp" placeholder="••••••" error={error} />
          <Button label={tr('Verify')} loading={busy} disabled={code.length < 6} onPress={verify} />
          <View style={{ alignItems: 'center', marginTop: 10 }}>
            {resendIn > 0 ? <T variant="small">{tr('Resend code in 0:')}{String(resendIn).padStart(2, '0')}</T> : <Button label={tr('Resend code')} kind="text" onPress={send} />}
          </View>
          {devCode ? <T variant="caption" style={{ textAlign: 'center', marginTop: 8 }}>{tr('Development build · code: {code}', { code: devCode })}</T> : null}
        </>
      ) : null}
      {step === 'locked' ? (
        <StateBlock icon="lock" tone="neutral" title={tr('Too many attempts')} body={tr('For your security, wait 10 minutes before requesting a new code.')} actions={[{ label: tr('Back to Verification'), onPress: () => router.back() }]} />
      ) : null}
      {step === 'verified' ? (
        <StateBlock icon="check" title={tr('Phone verified')} body={tr('Your number stays private. Other people only see Phone verified on your profile.')} actions={[{ label: tr('Done'), onPress: () => router.back() }]} />
      ) : null}
    </Screen>
  );
}
