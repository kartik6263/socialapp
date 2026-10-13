import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { verificationApi, type OrganizerStatus, type Signal, type VerificationStatus } from '@/api';
import { SignalExplainer, TrustSignals, signalMeaning } from '@/components/TrustSignals';
import { Button, ErrorBlock, Group, Header, Icon, IconTile, Note, Pill, Screen, SectionTitle, Skeleton, StateBlock, T, type IconName } from '@/components/ui';
import { useMe } from '@/context/AuthContext';
import { useFocusData } from '@/hooks/useAsync';
import { signalLabel } from '@/lib/format';
import { colors, type PillTone } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const V: Record<VerificationStatus, [string, PillTone]> = {
  NOT_STARTED: ['Not verified', 'neutral'], PENDING: ['Verification pending', 'blue'], IN_PROGRESS: ['In progress', 'blue'],
  VERIFIED: ['Verified', 'ok'], NEEDS_ATTENTION: ['Needs attention', 'warn'], EXPIRED: ['Expired', 'neutral'],
  FAILED: ['Couldn’t be completed', 'bad'], UNAVAILABLE: ['Unavailable', 'neutral'],
};

const O: Record<OrganizerStatus, [string, PillTone, string, string | null]> = {
  NONE: ['Not started', 'neutral', 'Only for people who host community or official events.', 'Learn more'],
  INCOMPLETE: ['Setup incomplete', 'neutral', 'Continue where you left off.', 'Continue'],
  SUBMITTED: ['Submitted', 'blue', 'We’ve received your details.', 'View'],
  IN_REVIEW: ['In review', 'blue', 'We’re checking the organisation’s details.', 'View'],
  MORE_INFO: ['More information needed', 'warn', 'Add the missing detail to continue.', 'View'],
  VERIFIED: ['Verified', 'ok', 'Your organizer profile shows Organizer verified.', 'View'],
  FAILED: ['Couldn’t be completed', 'bad', 'We couldn’t confirm the organisation’s details.', 'Try again'],
  EXPIRED: ['Expired', 'neutral', 'Official status is paused until you verify again.', 'Verify again'],
  UNAVAILABLE: ['Unavailable', 'neutral', 'Organizer verification isn’t currently available.', null],
};

const ID_SUB: Record<VerificationStatus, [string, string | null]> = {
  NOT_STARTED: ['Adds Identity verified to your profile. Takes about 3 minutes.', 'Verify'],
  PENDING: ['We’re processing your verification. We’ll notify you when it’s done.', 'View'],
  IN_PROGRESS: ['We’re processing your verification. We’ll notify you when it’s done.', 'View'],
  VERIFIED: ['Shown on your profile as Identity verified.', null],
  NEEDS_ATTENTION: ['Your ID expires soon. Verify again to keep the signal after that.', 'Verify again'],
  EXPIRED: ['The signal is no longer shown on your profile. Verify again to add it back.', 'Verify again'],
  FAILED: ['Your last attempt couldn’t be matched. Nothing was added to your profile.', 'Try again'],
  UNAVAILABLE: ['Identity verification isn’t currently available. Your profile works normally without it.', null],
};

export default function VerificationCenter() {
  useLanguage();
  const me = useMe();
  const { data: v, error, loading, refresh } = useFocusData(() => verificationApi.state());
  const [explain, setExplain] = useState<Signal | 'about' | null>(null);

  const row = (icon: IconName, label: string, status: [string, PillTone], sub: string, cta: string | null, run: () => void) => (
    <View style={{ flexDirection: 'row', gap: 12, padding: 14 }}>
      <IconTile name={icon} tone={status[1] === 'ok' ? 'ok' : 'neutral'} />
      <View style={{ flex: 1, gap: 4 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <T variant="bodyStrong">{label}</T>
          <Pill label={tr(status[0])} tone={status[1]} />
        </View>
        <T variant="small">{tr(sub)}</T>
        {cta ? <Button label={tr(cta)} compact kind="secondary" onPress={run} style={{ alignSelf: 'flex-start', marginTop: 4 }} /> : null}
      </View>
    </View>
  );

  return (
    <Screen>
      <Header kicker={tr('PROFILE')} title={tr('Verification')} />
      <T variant="body">{tr('Complete verification to add useful trust signals to your profile.')}</T>
      {loading ? <Skeleton rows={4} /> : error && !v ? (
        error.isNetwork ? (
          <StateBlock icon="wifi-off" tone="neutral" title={tr('Verification status unavailable while offline')} body={tr('We don’t show saved verification status offline, so nothing here can be out of date.')} actions={[{ label: tr('Retry'), onPress: refresh }]} />
        ) : <ErrorBlock error={error} onRetry={refresh} title={tr('We couldn’t load verification status')} />
      ) : v ? (
        <>
          {me.signals.length ? (
            <Group style={{ padding: 14, marginTop: 14 }}>
              <T variant="kicker" style={{ color: colors.inkSoft, marginBottom: 8 }}>{tr('SHOWN ON YOUR PROFILE')}</T>
              <TrustSignals signals={me.signals} name="You" />
            </Group>
          ) : (
            <Group style={{ padding: 14, marginTop: 14 }}>
              <T variant="bodyStrong">{tr('No verification completed yet')}</T>
              <T variant="small" style={{ marginTop: 4 }}>{tr('Complete available verification steps to add trust signals to your profile. Your profile works normally either way.')}</T>
            </Group>
          )}

          <SectionTitle title={tr('Identity')} />
          <Group>{row('user', tr('Identity verification'), V[v.identity.status], ID_SUB[v.identity.status][0], ID_SUB[v.identity.status][1], () => router.push('/verify/identity'))}</Group>

          <SectionTitle title={tr('Contact')} />
          <Group>
            {row('lock', tr('Phone verification'), V[v.phone.status], v.phone.status === 'VERIFIED' ? tr('{v} · Shown as Phone verified', { v: v.phone.masked ?? '' }) : tr('Confirm your number with a one-time code.'), v.phone.status === 'VERIFIED' ? null : tr('Verify'), () => router.push('/verify/phone'))}
            <View style={{ height: 1, backgroundColor: colors.divider }} />
            {row('message-circle', tr('Email verification'), V[v.email.status], v.email.status === 'VERIFIED' ? tr('{v} · Shown as Email verified', { v: v.email.masked ?? '' }) : v.email.status === 'PENDING' ? tr('Link sent to {masked}', { masked: v.email.masked }) : tr('Confirm your email with a link.'), v.email.status === 'VERIFIED' ? null : v.email.status === 'PENDING' ? tr('View') : tr('Verify'), () => router.push('/verify/email'))}
          </Group>

          <SectionTitle title={tr('Organizer')} />
          <Group>
            {row('users', tr('Organizer verification'), [O[v.organizer.status][0], O[v.organizer.status][1]], O[v.organizer.status][2], O[v.organizer.status][3], () =>
              router.push(v.organizer.status === 'NONE' || v.organizer.status === 'INCOMPLETE' || v.organizer.status === 'FAILED' ? '/organizer/setup' : '/verify/organizer'))}
          </Group>

          <SectionTitle title={tr('What these mean')} />
          <Group>
            {(['IDENTITY', 'PHONE', 'EMAIL', 'ORGANIZER', 'OFFICIAL'] as Signal[]).map((s, i) => (
              <Pressable key={s} onPress={() => setExplain(s)} style={{ flexDirection: 'row', alignItems: 'center', padding: 14, borderTopWidth: i ? 1 : 0, borderTopColor: colors.divider }} accessibilityRole="button">
                <View style={{ flex: 1 }}>
                  <T variant="bodyStrong">{signalLabel(s)}</T>
                  <T variant="small">{signalMeaning(s)}</T>
                </View>
                <Icon name="arrow-right" size={14} color={colors.brand} />
              </Pressable>
            ))}
            <Pressable onPress={() => setExplain('about')} style={{ flexDirection: 'row', alignItems: 'center', padding: 14, borderTopWidth: 1, borderTopColor: colors.divider }} accessibilityRole="button">
              <View style={{ flex: 1 }}>
                <T variant="bodyStrong">{tr('About trust signals')}</T>
                <T variant="small">{tr('Why you see them, and what they never mean')}</T>
              </View>
              <Icon name="arrow-right" size={14} color={colors.brand} />
            </Pressable>
          </Group>
          <View style={{ marginTop: 14 }}>
            <Note icon="lock">{tr('Your privacy matters. People see the result — like Identity verified — never your documents, ID number, phone number or email address.')}</Note>
          </View>
        </>
      ) : null}
      <SignalExplainer explain={explain === 'about' ? { kind: 'about' } : explain ? { kind: 'signal', signal: explain } : null} onClose={() => setExplain(null)} />
    </Screen>
  );
}
