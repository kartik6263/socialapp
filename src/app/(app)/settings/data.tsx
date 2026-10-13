import { File, Paths } from 'expo-file-system';
import { router } from 'expo-router';
import * as Sharing from 'expo-sharing';
import { useCallback, useEffect, useState } from 'react';
import { View } from 'react-native';
import { ApiError, privacyApi, setAnalyticsAllowed, type Consents } from '@/api';
import { Banner, Button, ErrorBlock, Group, Header, Note, Row, Screen, SectionTitle, Skeleton, T, ToggleRow } from '@/components/ui';
import { useMe } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { tr, useLanguage } from '@/i18n';

const KIND_LABEL: Record<string, string> = {
  TERMS: 'Terms of service', PRIVACY_POLICY: 'Privacy policy', AGE_18_PLUS: 'Confirmed 18 or older',
  ANALYTICS: 'Product analytics', OFFERS: 'Offers & promotions', MARKETING_EMAILS: 'Update emails',
};

/** Your data: download a copy, change optional consents, see the consent record, delete the account. */
export default function YourData() {
  useLanguage();
  const me = useMe();
  const toast = useToast();
  const [c, setC] = useState<Consents | null>(null);
  const [loadError, setLoadError] = useState<ApiError | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [showHistory, setShowHistory] = useState(false);

  const load = useCallback(() => {
    setLoadError(null);
    privacyApi.consents().then(setC).catch((e) => setLoadError(e instanceof ApiError ? e : new ApiError(0, 'ERROR', tr('Couldn’t load this'))));
  }, []);
  useEffect(load, [load]);

  const save = async (patch: Partial<Pick<Consents, 'analytics' | 'offers' | 'marketingEmails'>>, label: string) => {
    if (!c) return;
    const next = { ...c, ...patch };
    setC(next); // optimistic; reverted below if the save fails
    setSaveError(null);
    try {
      const saved = await privacyApi.saveConsents({ analytics: next.analytics, offers: next.offers, marketingEmails: next.marketingEmails, source: 'SETTINGS' });
      setC(saved);
      setAnalyticsAllowed(saved.analytics);
      toast(label);
    } catch (e) {
      setC(c);
      setSaveError(e instanceof ApiError ? e.message : tr('Couldn’t save. Try again.'));
    }
  };

  const download = async () => {
    setExporting(true);
    try {
      const data = await privacyApi.exportData();
      const file = new File(Paths.cache, `plans-data-${me.id}.json`);
      if (file.exists) file.delete();
      file.create();
      file.write(JSON.stringify(data, null, 2));
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(file.uri, { mimeType: 'application/json', dialogTitle: tr('Save your Plans data'), UTI: 'public.json' });
      } else {
        toast(tr('Saved to {path}', { path: file.uri }));
      }
    } catch (e) {
      toast(e instanceof ApiError ? e.message : tr('Couldn’t prepare your data. Try again.'));
    } finally {
      setExporting(false);
    }
  };

  return (
    <Screen>
      <Header kicker={tr('PRIVACY')} title={tr('Your data')} />
      <T variant="body">{tr('See what we hold, choose what’s optional, and leave whenever you like.')}</T>

      <SectionTitle title={tr('Download')} />
      <Group>
        <Row first icon="download" label={tr('Download your data')} sub={tr('Profile, settings, Plans, connections, messages you sent, reports you made and consents, as a JSON file.')} />
      </Group>
      <Button label={exporting ? tr('Preparing…') : tr('Download a copy')} icon="download" kind="secondary" loading={exporting} onPress={download} style={{ marginTop: 10 }} />

      <SectionTitle title={tr('Data & consent')} />
      {loadError ? <ErrorBlock error={loadError} onRetry={load} /> : !c ? <Skeleton rows={3} /> : (
        <>
          {saveError ? <View style={{ marginBottom: 10 }}><Banner icon="alert-circle" tone="bad" title={saveError} /></View> : null}
          <Group>
            <ToggleRow
              first
              label={tr('Product analytics')}
              sub={tr('Counts of actions like “Plan joined” to improve Plans. Never message content or location. Turning this off also unlinks past events from you.')}
              value={c.analytics}
              onChange={(v) => save({ analytics: v }, v ? tr('Analytics on') : tr('Analytics off'))}
            />
            <ToggleRow
              label={tr('Offers & promotions')}
              sub={tr('Occasional in-app notifications about deals on events.')}
              value={c.offers}
              onChange={(v) => save({ offers: v }, v ? tr('Offers on') : tr('Offers off'))}
            />
            <ToggleRow
              label={tr('Update emails')}
              sub={tr('News about Plans by email. Every email has an unsubscribe link. Security emails you request are always sent.')}
              value={c.marketingEmails}
              onChange={(v) => save({ marketingEmails: v }, v ? tr('Update emails on') : tr('Update emails off'))}
            />
          </Group>
          <Note icon="check">{tr('Needed to run your account and always on: sign-in, your profile, Plans, messages and safety tools.')}</Note>

          <Button label={showHistory ? tr('Hide consent record') : tr('Show consent record')} kind="text" onPress={() => setShowHistory(!showHistory)} style={{ marginTop: 6 }} />
          {showHistory ? (
            <Group>
              {c.history.length ? c.history.slice().reverse().map((h, i) => (
                <Row
                  key={`${h.kind}-${h.at}-${i}`}
                  first={i === 0}
                  icon={h.granted ? 'check-circle' : 'x-circle'}
                  label={tr(KIND_LABEL[h.kind] ?? h.kind)}
                  sub={`${h.granted ? tr('Agreed') : tr('Declined')} · ${new Date(h.at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })} · v${h.version}`}
                />
              )) : <Row first icon="info" label={tr('No choices recorded yet')} />}
            </Group>
          ) : null}
        </>
      )}

      <SectionTitle title={tr('Policies')} />
      <Group>
        <Row first icon="lock" label={tr('Privacy policy')} onPress={() => router.push({ pathname: '/legal/[slug]', params: { slug: 'privacy' } })} />
        <Row icon="database" label={tr('Cookie & storage policy')} onPress={() => router.push({ pathname: '/legal/[slug]', params: { slug: 'cookie-policy' } })} />
        <Row icon="package" label={tr('Third-party services')} onPress={() => router.push('/legal/licenses')} />
      </Group>

      <SectionTitle title={tr('Delete')} danger />
      <Group danger>
        <Row first icon="trash-2" danger label={tr('Delete your account')} sub={tr('Your data is removed after a 30-day grace period. You can cancel during that time.')} onPress={() => router.push('/settings/lifecycle')} />
      </Group>
    </Screen>
  );
}
