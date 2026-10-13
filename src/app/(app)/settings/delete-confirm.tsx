import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { ApiError, meApi } from '@/api';
import { Banner, Button, Field, Header, IconTile, Screen, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { tr, useLanguage } from '@/i18n';

export default function DeleteConfirm() {
  useLanguage();
  const { refreshUser } = useAuth();
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const go = async () => {
    setBusy(true);
    setError(null);
    try {
      await meApi.requestDeletion();
      // Account state flips to DELETION_REQUESTED; the root navigator shows the pending screen.
      await refreshUser();
    } catch (e) {
      setError(e instanceof ApiError && e.isNetwork ? tr('You’re offline. Reconnect to continue. Nothing was changed.') : e instanceof ApiError ? e.message : tr('Couldn’t delete your account. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen>
      <Header kicker={tr('ACCOUNT LIFECYCLE')} title={tr('Delete account')} />
      {error ? <View style={{ marginBottom: 12 }}><Banner icon="refresh-cw" tone="bad" title={error} /></View> : null}
      <IconTile name="trash-2" tone="bad" size={52} />
      <T variant="title" style={{ marginTop: 14 }}>{tr('Are you sure?')}</T>
      <T variant="body" style={{ marginVertical: 8 }}>{tr('This action can’t be easily undone. Your profile, connections and Plans will be removed as described on the previous screen.')}</T>
      <Field label={tr('Type DELETE to confirm')} value={text} onChangeText={setText} autoCapitalize="characters" autoCorrect={false} hint={tr('Capital letters, exactly as shown.')} />
      <View style={{ gap: 8 }}>
        <Button label={tr('Delete account')} kind="dangerSolid" disabled={text !== 'DELETE'} loading={busy} onPress={go} />
        <Button label={tr('Keep account')} kind="secondary" onPress={() => router.dismissTo('/settings')} />
      </View>
    </Screen>
  );
}
