import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Text } from 'react-native';
import { ApiError, meApi, type Channel } from '@/api';
import { Button, Field, Header, Screen, StateBlock, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

/** Change email/phone: enter the new value, confirm with a one-time code sent to it. */
export default function ChangeContact() {
  useLanguage();
  const { channel } = useLocalSearchParams<{ channel: Channel }>();
  const email = channel === 'EMAIL';
  const me = useMe();
  const { setUser } = useAuth();
  const [step, setStep] = useState<'enter' | 'code' | 'done'>('enter');
  const [value, setValue] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [devCode, setDevCode] = useState<string | null>(null);

  const normalized = email ? value.trim().toLowerCase() : `+91${value.replace(/\D/g, '')}`;
  const masked = email ? value.trim().replace(/^(.).*(@.*)$/, '$1••••$2') : `+91 ••••••${value.replace(/\D/g, '').slice(-4)}`;

  const send = async () => {
    const valid = email ? /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim()) : value.replace(/\D/g, '').length === 10;
    if (!valid) return setError(email ? tr('Enter a valid email address.') : tr('Enter a valid 10-digit mobile number.'));
    setBusy(true);
    setError(null);
    try {
      const r = await meApi.startContactChange(channel, normalized);
      setDevCode(r.devCode ?? null);
      setStep('code');
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t send a code.'));
    } finally {
      setBusy(false);
    }
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      setUser(await meApi.confirmContactChange(channel, normalized, code));
      setStep('done');
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('That code didn’t work.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen>
      <Header kicker={tr('ACCOUNT INFORMATION')} title={email ? tr('Change email') : tr('Change phone')} />
      {step === 'enter' ? (
        <>
          <T variant="body" style={{ marginBottom: 14 }}>{trRich(email ? 'Current email: {value}' : 'Current phone number: {value}', { value: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{(email ? me.maskedEmail : me.maskedPhone) ?? tr('Not added')}</Text> })}</T>
          <Field
            label={(email ? tr('New email') : tr('New phone number'))}
            value={value}
            onChangeText={(t) => { setValue(t); setError(null); }}
            keyboardType={email ? 'email-address' : 'phone-pad'}
            autoCapitalize="none"
            prefix={email ? undefined : '+91'}
            placeholder={email ? tr('name@example.com') : '98765 43210'}
            error={error}
          />
          <T variant="small">{email ? tr('Your email is private. People only ever see Email verified.') : tr('Your number is private. People only ever see Phone verified.')}</T>
          <Button label={tr('Send code')} loading={busy} onPress={send} style={{ marginTop: 16 }} />
        </>
      ) : step === 'code' ? (
        <>
          <T variant="title">{tr('Enter the code')}</T>
          <T variant="body" style={{ marginVertical: 8 }}>{trRich(email ? 'We sent a 6-digit code to {destination}. Your current email stays active until you confirm.' : 'We sent a 6-digit code to {destination}. Your current number stays active until you confirm.', { destination: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{masked}</Text> })}</T>
          <Field label={tr('6-digit verification code')} value={code} onChangeText={(t) => setCode(t.replace(/\D/g, '').slice(0, 6))} keyboardType="number-pad" textContentType="oneTimeCode" placeholder="••••••" error={error} />
          <Button label={tr('Verify')} loading={busy} disabled={code.length < 6} onPress={confirm} />
          {devCode ? <T variant="caption" style={{ textAlign: 'center', marginTop: 8 }}>{tr('Development build · code: {code}', { code: devCode })}</T> : null}
        </>
      ) : (
        <StateBlock
          icon="check"
          title={email ? tr('Email updated') : tr('Phone number updated')}
          body={email ? tr('Your new email is verified and stays private.') : tr('Your new number is verified and stays private. It’s used for sign-in codes.')}
          actions={[{ label: tr('Done'), onPress: () => router.back() }]}
        />
      )}
    </Screen>
  );
}
