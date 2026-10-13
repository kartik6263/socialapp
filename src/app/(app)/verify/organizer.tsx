import { router } from 'expo-router';
import { View } from 'react-native';
import { verificationApi } from '@/api';
import { Avatar, Banner, ErrorBlock, Header, Loading, Pill, Screen, StateBlock, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function OrganizerVerification() {
  useLanguage();
  const { data: v, error, loading, refresh } = useFocusData(() => verificationApi.state());
  if (loading) return <Screen><Header kicker={tr('VERIFICATION')} title={tr('Organizer verification')} /><Loading /></Screen>;
  if (!v) return <Screen><Header kicker={tr('VERIFICATION')} title={tr('Organizer verification')} />{error ? <ErrorBlock error={error} onRetry={refresh} /> : null}</Screen>;

  const o = v.organizer;
  const name = o.name ?? tr('Your organizer profile');

  return (
    <Screen>
      <Header kicker={tr('VERIFICATION')} title={tr('Organizer verification')} />
      {o.status !== 'NONE' ? (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: '#fff', borderRadius: 18, borderWidth: 1, borderColor: colors.line, padding: 14, marginBottom: 14 }}>
          <Avatar name={name} id={o.organizerId ?? 0} size={44} tone="mint" />
          <View style={{ flex: 1, gap: 4 }}>
            <T variant="kicker" style={{ color: colors.inkSoft }}>{tr('YOUR ORGANIZER PROFILE')}</T>
            <T variant="bodyStrong">{name}</T>
            <Pill label={{ SUBMITTED: tr('Submitted'), IN_REVIEW: tr('In review'), VERIFIED: tr('Organizer verified'), FAILED: tr('Couldn’t be completed'), MORE_INFO: tr('More information needed'), INCOMPLETE: tr('Setup incomplete'), EXPIRED: tr('Expired'), UNAVAILABLE: tr('Unavailable'), NONE: '' }[o.status]} tone={o.status === 'VERIFIED' ? 'ok' : o.status === 'FAILED' ? 'bad' : o.status === 'MORE_INFO' ? 'warn' : 'blue'} />
          </View>
        </View>
      ) : null}
      {o.status === 'NONE' || o.status === 'INCOMPLETE' ? (
        <StateBlock icon="users" title={tr('Become an organizer')} body={tr('For people who host community or official events. It confirms the organisation you host for — it’s separate from your personal Identity verified signal.')} actions={[{ label: o.status === 'NONE' ? tr('Start organizer verification') : tr('Continue setup'), onPress: () => router.replace('/organizer/setup') }]} />
      ) : o.status === 'SUBMITTED' || o.status === 'IN_REVIEW' ? (
        <Banner icon="clock" tone="blue" title={tr('In review')} body={tr('We’re checking the organisation’s details. This usually takes 1–2 working days. We’ll notify you.')} />
      ) : o.status === 'MORE_INFO' ? (
        <StateBlock icon="info" tone="warn" title={tr('More information needed')} body={tr('Check your email from Plans for what’s missing, then update your details.')} actions={[{ label: tr('Update details'), onPress: () => router.replace('/organizer/setup') }]} />
      ) : o.status === 'VERIFIED' ? (
        <StateBlock icon="check" title={tr('Organizer verified')} body={tr('{name} shows Organizer verified. Your personal profile signals haven’t changed.', { name })} actions={[{ label: tr('View organizer profile'), onPress: () => router.replace(`/organizer/${o.organizerId}`) }]} />
      ) : o.status === 'FAILED' ? (
        <StateBlock icon="refresh-cw" tone="bad" title={tr('Organizer verification couldn’t be completed')} body={tr('We couldn’t confirm the organisation’s details. Check the website and contact email, then try again.')} actions={[{ label: tr('Try again'), onPress: () => router.replace('/organizer/setup') }, { label: tr('Exit'), kind: 'secondary', onPress: () => router.back() }]} />
      ) : (
        <StateBlock icon="clock" tone="neutral" title={tr('Organizer verification isn’t currently available')} body={tr('It’s temporarily unavailable. You can still create Plans as usual.')} actions={[{ label: tr('Back to Verification'), onPress: () => router.back() }]} />
      )}
      <T variant="small" style={{ marginTop: 16 }}>{tr('We don’t share internal review notes. Organizer verification doesn’t change your personal trust signals.')}</T>
    </Screen>
  );
}
