import { Linking } from 'react-native';
import { Group, Header, Note, Row, Screen, SectionTitle, T } from '@/components/ui';
import { appVersion, business, emailOrNull, isPlaceholder } from '@/lib/business';
import { tr, useLanguage } from '@/i18n';

/** Who runs Plans and how to reach them: required in-app disclosure (IT Rules 2021 grievance officer, app store contact). */
export default function BusinessDetails() {
  useLanguage();
  const show = (v: string) => (isPlaceholder(v) ? tr('To be added') : v);
  const mail = (address: string, subject: string) => {
    const to = emailOrNull(address);
    return to ? () => void Linking.openURL(`mailto:${to}?subject=${encodeURIComponent(subject)}`) : undefined;
  };

  return (
    <Screen>
      <Header kicker={tr('ABOUT')} title={tr('Business details')} />
      <T variant="body">{tr('Plans is a product of the company below. Use these details for legal, privacy or grievance matters.')}</T>

      <SectionTitle title={tr('Company')} />
      <Group>
        <Row first icon="briefcase" label={tr('Legal name')} value={show(business.legalName)} />
        <Row icon="map-pin" label={tr('Registered address')} sub={show(business.registeredAddress)} />
        <Row icon="hash" label={tr('Company registration (CIN)')} value={show(business.cin)} />
        <Row icon="file-text" label={tr('GSTIN')} value={show(business.gstin)} />
      </Group>

      <SectionTitle title={tr('Contact')} />
      <Group>
        <Row first icon="mail" label={tr('Support')} value={show(business.supportEmail)} onPress={mail(business.supportEmail, 'Plans support')} />
        <Row icon="lock" label={tr('Privacy & data requests')} value={show(business.privacyEmail)} onPress={mail(business.privacyEmail, 'Privacy request')} />
      </Group>

      <SectionTitle title={tr('Grievance Officer')} />
      <Group>
        <Row first icon="user" label={tr('Name')} value={show(business.grievanceOfficer.name)} />
        <Row icon="mail" label={tr('Email')} value={show(business.grievanceOfficer.email)} onPress={mail(business.grievanceOfficer.email, 'Grievance')} />
        <Row icon="clock" label={tr('First response')} value={show(business.responseTime)} />
      </Group>
      <T variant="small" style={{ marginTop: 8 }}>
        {tr('If your complaint isn’t resolved, you can escalate it to the Data Protection Board of India.')}
      </T>

      <SectionTitle title={tr('Delete your data without the app')} />
      <Note icon="trash-2">
        {tr('Signed in? Use Settings → Deactivate or delete. Can’t sign in? Email the privacy address above from the email or phone number on your account, and we’ll verify it’s you and delete your data.')}
      </Note>

      <T variant="caption" style={{ marginTop: 18, textAlign: 'center' }}>{tr('Plans version {v}', { v: appVersion })}</T>
    </Screen>
  );
}
