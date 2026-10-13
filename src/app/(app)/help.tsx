import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { Linking } from 'react-native';
import { contentApi } from '@/api';
import { EmergencyNote, Group, Header, Row, Screen, SectionTitle, T } from '@/components/ui';
import { useMe } from '@/context/AuthContext';
import { appVersion, business, emailOrNull } from '@/lib/business';
import { openReport } from '@/lib/report';
import { tr, useLanguage } from '@/i18n';

/**
 * Real ways to get help. "Report a problem" goes to the team's queue in the Admin Console; email opens the mail app
 * with the details support needs (no message is ever claimed as sent unless it was).
 */
export default function Help() {
  useLanguage();
  const me = useMe();
  const [hasFaq, setHasFaq] = useState(false);
  useEffect(() => {
    contentApi.page('faq').then(() => setHasFaq(true)).catch(() => setHasFaq(false));
  }, []);

  const support = emailOrNull(business.supportEmail);
  const emailSupport = support
    ? () => {
        const body = `\n\n—\n${tr('Please keep this so we can find your account')}:\nAccount #${me.id} · Plans ${appVersion}`;
        void Linking.openURL(`mailto:${support}?subject=${encodeURIComponent('Plans support')}&body=${encodeURIComponent(body)}`);
      }
    : undefined;

  return (
    <Screen>
      <Header kicker={tr('SUPPORT')} title={tr('Help & support')} />
      <T variant="body">{tr('Tell us what’s wrong and we’ll look into it. Replies come by email or in your notifications.')}</T>

      <SectionTitle title={tr('Get help')} />
      <Group>
        {hasFaq ? <Row first icon="help-circle" label={tr('Help & FAQ')} sub={tr('Answers to common questions')} onPress={() => router.push({ pathname: '/legal/[slug]', params: { slug: 'faq' } })} /> : null}
        <Row
          first={!hasFaq}
          icon="message-square"
          label={tr('Report a problem')}
          sub={tr('Something isn’t working, or you need help with your account')}
          onPress={() => openReport({ targetType: 'PROBLEM', title: tr('A problem with Plans') })}
        />
        {emailSupport ? <Row icon="mail" label={tr('Email support')} value={support ?? undefined} onPress={emailSupport} /> : null}
        <Row icon="shield" label={tr('Safety Center')} sub={tr('Report a person or Plan, block, and safety tips')} onPress={() => router.push('/safety')} />
      </Group>

      <SectionTitle title={tr('Your account')} />
      <Group>
        <Row first icon="download" label={tr('Your data & consent')} onPress={() => router.push('/settings/data')} />
        <Row icon="briefcase" label={tr('Business details & Grievance Officer')} onPress={() => router.push('/legal/business')} />
        <Row icon="file-text" label={tr('Legal & privacy')} onPress={() => router.push('/legal')} />
      </Group>

      <SectionTitle title={tr('In an emergency')} />
      <EmergencyNote />
    </Screen>
  );
}
