import { router } from 'expo-router';
import { Group, Header, Row, Screen, SectionTitle, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { tr, useLanguage } from '@/i18n';

/** Every policy and legal detail in one place. Works signed out, so people can read it before creating an account. */
export default function LegalHub() {
  useLanguage();
  const { user } = useAuth();
  const signedIn = !!user && user.onboarded;
  const page = (slug: string) => () => router.push({ pathname: '/legal/[slug]', params: { slug } });

  return (
    <Screen>
      <Header kicker={tr('PLANS')} title={tr('Legal & privacy')} />
      <T variant="body">{tr('Plain-language policies. You can read them any time, signed in or not.')}</T>

      <SectionTitle title={tr('Policies')} />
      <Group>
        <Row first icon="lock" label={tr('Privacy policy')} sub={tr('What we collect, why, and your rights')} onPress={page('privacy')} />
        <Row icon="file-text" label={tr('Terms of service')} sub={tr('The agreement for using Plans')} onPress={page('terms')} />
        <Row icon="rotate-ccw" label={tr('Refund policy')} sub={tr('Paid event tickets and refunds')} onPress={page('refund-policy')} />
        <Row icon="database" label={tr('Cookie & storage policy')} sub={tr('What the app keeps on your phone')} onPress={page('cookie-policy')} />
        {signedIn ? <Row icon="flag" label={tr('Community guidelines')} onPress={() => router.push('/safety/guidelines')} /> : null}
      </Group>

      <SectionTitle title={tr('Your data')} />
      <Group>
        {signedIn ? (
          <>
            <Row first icon="download" label={tr('Download your data')} sub={tr('Get a copy of everything we hold about you')} onPress={() => router.push('/settings/data')} />
            <Row icon="sliders" label={tr('Data & consent')} sub={tr('Analytics, offers and emails')} onPress={() => router.push('/settings/data')} />
            <Row icon="trash-2" label={tr('Delete your account')} sub={tr('Removes your data after a 30-day grace period')} onPress={() => router.push('/settings/lifecycle')} />
          </>
        ) : (
          <Row first icon="trash-2" label={tr('Delete an account without the app')} sub={tr('How to ask us to delete your data')} onPress={() => router.push('/legal/business')} />
        )}
      </Group>

      <SectionTitle title={tr('About')} />
      <Group>
        <Row first icon="briefcase" label={tr('Business details')} sub={tr('Who runs Plans, and the Grievance Officer')} onPress={() => router.push('/legal/business')} />
        <Row icon="package" label={tr('Third-party services & licences')} sub={tr('Every SDK in the app, and fonts and images')} onPress={() => router.push('/legal/licenses')} />
        <Row icon="eye" label={tr('Accessibility')} sub={tr('How Plans works with assistive technology')} onPress={() => router.push('/legal/accessibility')} />
      </Group>
    </Screen>
  );
}
