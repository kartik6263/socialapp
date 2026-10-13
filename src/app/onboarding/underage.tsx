import { useState } from 'react';
import { View } from 'react-native';
import { ApiError, privacyApi } from '@/api';
import { Banner, Button, IconTile, Logo, Note, Screen, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { tr, useLanguage } from '@/i18n';

/**
 * Plans is for adults. Someone under 18 can't continue, and we don't keep their details: one tap erases the account
 * straight away (no grace period) and signs them out. Their birth year was never saved.
 */
export default function Underage() {
  useLanguage();
  const { signOut } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const erase = async () => {
    setBusy(true);
    setError(null);
    try {
      await privacyApi.deleteUnderage();
      await signOut();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t delete your details. Try again.'));
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <View style={{ paddingVertical: 16 }}><Logo /></View>
      <View style={{ marginTop: 40, gap: 12 }}>
        <IconTile name="user-x" tone="neutral" size={56} />
        <T variant="kicker">{tr('ADULTS ONLY')}</T>
        <T variant="display" accessibilityRole="header">{tr('Plans is for people aged 18 and over')}</T>
        <T variant="body" style={{ fontSize: 15, lineHeight: 22 }}>
          {tr('Because Plans helps people meet in person, we only allow adults. We haven’t saved your birth year, and we’ll delete the sign-in details you gave us now.')}
        </T>
        {error ? <Banner icon="alert-circle" tone="bad" title={error} /> : null}
        <Button label={tr('Delete my details and exit')} onPress={erase} loading={busy} style={{ marginTop: 10 }} />
        <Note icon="info">{tr('Entered the wrong year by mistake? Deleting now means you can sign up again with the correct one.')}</Note>
      </View>
    </Screen>
  );
}
