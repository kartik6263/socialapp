import { router } from 'expo-router';
import { useState } from 'react';
import { Text } from 'react-native';
import { ApiError, meApi } from '@/api';
import { Banner, Button, Field, Header, Screen, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

export default function ChangeName() {
  useLanguage();
  const me = useMe();
  const { setUser } = useAuth();
  const toast = useToast();
  const [name, setName] = useState(me.displayName);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const identityVerified = me.signals.includes('IDENTITY');

  const save = async () => {
    if (name.trim().length < 2) return setError(tr('Enter at least 2 characters.'));
    if (name.trim() === me.displayName) return router.back();
    setBusy(true);
    try {
      setUser(await meApi.updateName(name.trim()));
      toast(tr('Name updated'));
      router.back();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen>
      <Header kicker={tr('ACCOUNT INFORMATION')} title={tr('Change name')} />
      <T variant="body" style={{ marginBottom: 14 }}>{trRich('Current name: {name}', { name: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{me.displayName}</Text> })}</T>
      <Field label={tr('New name')} value={name} onChangeText={(t) => { setName(t); setError(null); }} autoComplete="name" error={error} />
      <T variant="small">{tr('Your name appears on your public profile and in Plans you join.')}</T>
      {identityVerified ? <Banner icon="shield" tone="neutral" title={tr('Because you’re Identity verified, a new name is re-checked before that signal shows again.')} /> : null}
      <Button label={tr('Save name')} loading={busy} onPress={save} style={{ marginTop: 16 }} />
    </Screen>
  );
}
