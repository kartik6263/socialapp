import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { ApiError, plansApi } from '@/api';
import { Banner, Button, Field, Header, IconTile, Screen, SectionTitle, T } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function Announcement() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const toast = useToast();
  const { data: plan } = useFocusData(() => plansApi.get(Number(id)), [id]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const publish = async () => {
    if (title.trim().length < 3) return setError(tr('Add a short headline.'));
    if (body.trim().length < 5) return setError(tr('Add the message participants need to know.'));
    setBusy(true);
    setError(null);
    try {
      await plansApi.announce(Number(id), title.trim(), body.trim());
      toast(tr('Announcement published and pinned.'));
      router.back();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t publish. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  const reach = plan ? `${Math.max(0, plan.participantCount - 1)} participants` : 'participants';

  return (
    <Screen edges={['top', 'bottom']}>
      <Header kicker={plan?.title.toUpperCase()} title={tr('Announcement')} />
      <T variant="body" style={{ marginBottom: 16 }}>{tr('Announcements are pinned in the Plan Group and sent to every participant. Use them for important Plan information.')}</T>
      <Field label={tr('Headline')} value={title} onChangeText={setTitle} maxLength={60} placeholder={tr('Meeting point update')} />
      <Field label={tr('Message')} value={body} onChangeText={setBody} multiline maxLength={500} hint={`${body.length}/500`} placeholder={tr('The group will meet at the west entrance at 9:45 AM.')} />
      {error ? <Banner icon="alert-circle" tone="bad" title={error} /> : null}

      <SectionTitle title={tr('Preview')} />
      <View style={styles.preview}>
        <Text style={styles.kicker}>{tr('IMPORTANT ANNOUNCEMENT')}</Text>
        <Text style={styles.body}><Text style={{ fontFamily: fonts.bodyBold }}>{title || tr('Headline')}</Text> {body || tr('Your message appears here.')}</Text>
        <T variant="caption">{plan?.host.name} · {plan?.host.subtitle} {tr('· Pinned')}</T>
      </View>
      <View style={styles.push}>
        <IconTile name="bell" size={34} />
        <View style={{ flex: 1 }}>
          <T variant="bodyStrong">{tr('Important update in {plan}', { plan: plan?.title })}</T>
          <T variant="small">{tr('How participants see the notification · {reach}', { reach })}</T>
        </View>
      </View>
      <Button label={tr('Publish announcement')} loading={busy} onPress={publish} style={{ marginTop: 18 }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  preview: { backgroundColor: '#e0edf2', borderRadius: 16, padding: 12, gap: 4 },
  kicker: { fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: '#2b5c74' },
  body: { fontFamily: fonts.body, fontSize: 13, lineHeight: 19, color: colors.ink },
  push: { flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 16, padding: 12, marginTop: 10 },
});
