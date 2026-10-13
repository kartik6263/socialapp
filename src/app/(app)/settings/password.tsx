import { router } from 'expo-router';
import { useState } from 'react';
import { Text, View } from 'react-native';
import { ApiError, meApi } from '@/api';
import { Banner, Button, Field, Header, Screen, StateBlock } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function ChangePassword() {
  useLanguage();
  const me = useMe();
  const { refreshUser } = useAuth();
  const [cur, setCur] = useState('');
  const [nw, setNw] = useState('');
  const [cf, setCf] = useState('');
  const [show, setShow] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  const rules = [
    [nw.length >= 8, tr('At least 8 characters')],
    [/\d/.test(nw), tr('Includes a number')],
    [/[A-Za-z]/.test(nw), tr('Includes a letter')],
    [!!nw && nw !== cur, tr('Different from your current password')],
    ...(cf ? [[cf === nw, cf === nw ? tr('Passwords match') : tr('Passwords don’t match')] as const] : []),
  ] as const;
  const valid = rules.every(([ok]) => ok) && cf === nw;

  const submit = async () => {
    if (!valid) return setError(tr('Check the password requirements.'));
    setBusy(true);
    setError(null);
    try {
      await meApi.changePassword(me.hasPassword ? cur : null, nw);
      await refreshUser();
      setDone(true);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t update your password.'));
    } finally {
      setBusy(false);
    }
  };

  if (done) {
    return (
      <Screen>
        <Header kicker={tr('SECURITY')} title={tr('Change password')} />
        <StateBlock icon="check" title={tr('Password updated')} body={tr('Your password has been changed successfully. Other devices stay signed in until you sign them out.')}
          actions={[{ label: tr('Review active sessions'), kind: 'secondary', onPress: () => router.replace('/settings/sessions') }, { label: tr('Done'), onPress: () => router.back() }]} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Header kicker={tr('SECURITY')} title={me.hasPassword ? tr('Change password') : tr('Set a password')} />
      {me.hasPassword ? <Field label={tr('Current password')} value={cur} onChangeText={setCur} secureTextEntry={!show} autoComplete="current-password" /> : null}
      <Field label={tr('New password')} value={nw} onChangeText={setNw} secureTextEntry={!show} autoComplete="new-password" />
      <Field label={tr('Confirm new password')} value={cf} onChangeText={setCf} secureTextEntry={!show} autoComplete="new-password" />
      <Button label={show ? tr('Hide passwords') : tr('Show passwords')} kind="text" compact onPress={() => setShow(!show)} style={{ alignSelf: 'flex-start' }} />
      <View style={{ gap: 4, marginVertical: 8 }} accessibilityLabel={tr('Password requirements')}>
        {rules.map(([ok, text]) => (
          <Text key={text} style={{ fontFamily: fonts.body, fontSize: 13, color: ok ? colors.brand : colors.inkSoft }}>
            <Text style={{ fontFamily: fonts.bodyBold }}>{ok ? '✓' : '○'}</Text>  {text}
          </Text>
        ))}
      </View>
      {error ? <Banner icon="alert-circle" tone="bad" title={error} /> : null}
      <Button label={busy ? tr('Updating…') : tr('Update password')} loading={busy} onPress={submit} style={{ marginTop: 12 }} />
    </Screen>
  );
}
