import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable } from 'react-native';
import { ConfirmDialog } from '@/components/Sheet';
import { Banner, Group, Header, Row, Screen, SectionTitle } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { signalLabel } from '@/lib/format';
import { shortChoice } from '@/lib/privacyChoices';
import Constants from 'expo-constants';
import { tr, useLanguage } from '@/i18n';

export default function SettingsHome() {
  useLanguage();
  const me = useMe();
  const { signOut } = useAuth();
  const [confirm, setConfirm] = useState(false);
  const verified = me.signals.filter((s) => s !== 'OFFICIAL').map((s) => signalLabel(s).replace(' verified', ''));

  return (
    <Screen>
      <Header kicker={me.displayName.toUpperCase()} title={tr('Settings')} />
      {me.accountStatus === 'RESTRICTED' ? (
        <Pressable onPress={() => router.push('/settings/restricted')}>
          <Banner icon="lock" tone="warn" title={tr('Some features are limited')} body={tr('See what’s affected on your account.')} action={tr('View')} onAction={() => router.push('/settings/restricted')} />
        </Pressable>
      ) : null}

      <SectionTitle title={tr('Account')} />
      <Group>
        <Row first icon="user" label={tr('Profile')} sub={tr('How others see you')} onPress={() => router.push('/me')} />
        <Row icon="settings" label={tr('Account information')} sub={tr('Name, email, phone')} onPress={() => router.push('/settings/account')} />
        <Row icon="shield" label={tr('Verification')} value={verified.length ? verified.join(', ') : tr('Not started')} onPress={() => router.push('/verify')} />
      </Group>

      <SectionTitle title={tr('Privacy')} />
      <Group>
        <Row first icon="eye" label={tr('Privacy')} sub={tr('Visibility, location, discovery and contact')} onPress={() => router.push('/settings/privacy')} />
        <Row icon="download" label={tr('Your data')} sub={tr('Download a copy, consent choices, deletion')} onPress={() => router.push('/settings/data')} />
      </Group>

      <SectionTitle title={tr('Notifications')} />
      <Group><Row first icon="bell" label={tr('Notification preferences')} sub={tr('Push and in-app')} onPress={() => router.push('/notifications/settings')} /></Group>

      <SectionTitle title={tr('Safety')} />
      <Group>
        <Row first icon="shield" label={tr('Safety Center')} sub={tr('Tools, guidelines and help')} onPress={() => router.push('/safety')} />
        <Row icon="lock" label={tr('Blocked people')} onPress={() => router.push('/safety/blocked')} />
        <Row icon="flag" label={tr('Your reports')} onPress={() => router.push('/safety/reports')} />
      </Group>

      <SectionTitle title={tr('Organizer')} />
      <Group>
        {me.organizer ? (
          <Row first icon="users" label={me.organizer.name} sub={tr('Organizer profile')} value={me.organizer.status === 'VERIFIED' ? tr('Verified') : tr('In progress')} onPress={() => router.push(me.organizer!.status === 'VERIFIED' ? `/organizer/${me.organizer!.id}` : '/verify/organizer')} />
        ) : (
          <Row first icon="users" label={tr('Become an organizer')} sub={tr('For community and official events')} onPress={() => router.push('/organizer/setup')} />
        )}
      </Group>

      <SectionTitle title={tr('Security')} />
      <Group>
        <Row first icon="key" label={tr('Security')} sub={tr('Password, sign-in and activity')} onPress={() => router.push('/settings/security')} />
        <Row icon="smartphone" label={tr('Active sessions')} onPress={() => router.push('/settings/sessions')} />
      </Group>

      <SectionTitle title={tr('Preferences')} />
      <Group>
        <Row first icon="globe" label={tr('Language')} value={shortChoice('language', me.privacy)} onPress={() => router.push('/settings/choice/language')} />
        <Row icon="eye" label={tr('Accessibility')} sub={tr('Follows your device’s text size and reduced-motion settings.')} onPress={() => router.push('/legal/accessibility')} />
      </Group>

      <SectionTitle title={tr('Help')} />
      <Group>
        <Row first icon="message-circle" label={tr('Help & support')} sub={tr('Report a problem or contact us')} onPress={() => router.push('/help')} />
        <Row icon="flag" label={tr('Community guidelines')} onPress={() => router.push('/safety/guidelines')} />
        <Row icon="file-text" label={tr('Legal & privacy')} sub={tr('Terms, privacy, refunds, cookies and licences')} onPress={() => router.push('/legal')} />
        <Row icon="briefcase" label={tr('About Plans')} sub={tr('Business details and Grievance Officer')} value={`v${Constants.expoConfig?.version ?? '1.0.0'}`} onPress={() => router.push('/legal/business')} />
      </Group>

      <SectionTitle title={tr('Account lifecycle')} danger />
      <Group danger><Row first icon="trash-2" danger label={tr('Deactivate or delete account')} sub={tr('Temporary or permanent — you choose')} onPress={() => router.push('/settings/lifecycle')} /></Group>

      <Group style={{ marginTop: 16 }}><Row first icon="log-out" label={tr('Sign out')} onPress={() => setConfirm(true)} /></Group>

      <ConfirmDialog visible={confirm} onClose={() => setConfirm(false)} title={tr('Sign out?')} body={tr('You can sign back in with a code to your phone or email.')} okLabel={tr('Sign out')} icon="log-out" onConfirm={signOut} />
    </Screen>
  );
}
