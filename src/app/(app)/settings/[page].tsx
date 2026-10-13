import { router, useLocalSearchParams } from 'expo-router';
import { useState, type ReactNode } from 'react';
import { View } from 'react-native';
import { meApi } from '@/api';
import { SaveErrorBanner } from '@/components/SaveErrorBanner';
import { ConfirmDialog } from '@/components/Sheet';
import { Button, Group, Header, Row, Screen, SectionTitle, StateBlock, T, ToggleRow } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { useSavePrivacy } from '@/hooks/useSavePrivacy';
import { relativeTime } from '@/lib/format';
import { shortChoice, type ChoiceKey } from '@/lib/privacyChoices';
import { tr, useLanguage } from '@/i18n';

const choice = (k: ChoiceKey) => () => router.push(`/settings/choice/${k}`);
const go = (p: string) => () => router.push(`/settings/${p}`);

interface Page {
  kicker: string;
  title: string;
  intro?: string;
  body: ReactNode;
  foot?: string;
}

export default function SettingsPage() {
  useLanguage();
  const { page } = useLocalSearchParams<{ page: string }>();
  const me = useMe();
  const { setUser } = useAuth();
  const { save, saveError, privacy: p } = useSavePrivacy();
  const [confirm, setConfirm] = useState<'deactivate' | null>(null);

  const area = p.areaLevel === 'CITY' ? me.city ?? me.area ?? '' : `${me.area ?? ''} area`;
  const discOn = [p.discoverPeople, p.discoverParticipants, p.discoverDestination, p.discoverSearch].filter(Boolean).length;
  const discSum = discOn === 4 ? tr('Everywhere') : discOn === 0 ? tr('Hidden from discovery') : tr('Limited');
  const toggle = (k: keyof typeof p, label: string) => (v: boolean) => save({ [k]: v }, `${label} ${v ? tr('turned on') : tr('turned off')}`);

  const pages: Record<string, Page> = {
    account: {
      kicker: 'SETTINGS', title: tr('Account information'),
      intro: tr('Public information appears on your profile. Private information is only used to run your account.'),
      body: (
        <>
          <SectionTitle title={tr('Public · shown on your profile')} />
          <Group>
            <Row first icon="user" label={tr('Name')} value={me.displayName} onPress={() => router.push('/settings/name')} />
            <Row icon="clock" label={tr('Age range')} sub={tr('Worked out from your birth year')} value={`${me.ageRange ?? '—'}${p.showAge ? '' : tr(' · hidden')}`} />
            <Row icon="map-pin" label={tr('Area')} value={area} onPress={go('location')} />
            <Row icon="settings" label={tr('Other profile details')} sub={tr('Bio, interests, languages, intent')} onPress={() => router.push('/edit-profile')} />
          </Group>
          <SectionTitle title={tr('Private · never shown to others')} />
          <Group>
            <Row first icon="message-circle" label={tr('Email')} value={me.maskedEmail ?? tr('Not added')} tag={tr('Private')} tagTone="neutral" onPress={() => router.push('/settings/contact/EMAIL')} />
            <Row icon="lock" label={tr('Phone')} value={me.maskedPhone ?? tr('Not added')} tag={tr('Private')} tagTone="neutral" onPress={() => router.push('/settings/contact/PHONE')} />
            <Row icon="clock" label={tr('Member since')} value={new Date(me.memberSince).toLocaleDateString('en-IN', { month: 'short', year: 'numeric' })} />
          </Group>
          <SectionTitle title={tr('Trust')} />
          <Group><Row first icon="shield" label={tr('Verification')} onPress={() => router.push('/verify')} /></Group>
          <SectionTitle title={tr('Your data')} />
          <Group><Row first icon="download" label={tr('Download your data')} sub={tr('Get a copy, and manage consent')} onPress={() => router.push('/settings/data')} /></Group>
          <SectionTitle title={tr('Account lifecycle')} danger />
          <Group danger><Row first icon="trash-2" danger label={tr('Deactivate or delete account')} onPress={go('lifecycle')} /></Group>
        </>
      ),
    },
    privacy: {
      kicker: 'SETTINGS', title: tr('Privacy'), intro: tr('Control what people can see and how they can interact with you.'),
      body: (
        <>
          <SectionTitle title={tr('Profile')} />
          <Group>
            <Row first icon="eye" label={tr('Profile visibility')} value={shortChoice('profileVisibility', p)} onPress={choice('profileVisibility')} />
            <Row icon="user" label={tr('Public profile fields')} sub={tr('Age range, intent, interests, Plans')} onPress={go('fields')} />
          </Group>
          <SectionTitle title={tr('Location')} />
          <Group><Row first icon="map-pin" label={tr('Approximate location')} sub={tr('Your exact address is never shown')} value={area} onPress={go('location')} /></Group>
          <SectionTitle title={tr('Discovery')} />
          <Group>
            <Row first icon="search" label={tr('Who can discover me')} value={discSum} onPress={go('discover')} />
            <Row icon="calendar" label={tr('Default Plan visibility')} value={shortChoice('defaultPlanVisibility', p)} onPress={choice('defaultPlanVisibility')} />
            <Row icon="map-pin" label={tr('Plan location')} value={shortChoice('planLocation', p)} onPress={choice('planLocation')} />
          </Group>
          <SectionTitle title={tr('Contact')} />
          <Group>
            <Row first icon="users" label={tr('Connection requests')} value={shortChoice('connectionRequests', p)} onPress={choice('connectionRequests')} />
            <Row icon="message-circle" label={tr('Messages')} value={shortChoice('messages', p)} onPress={choice('messages')} />
            <Row icon="lock" label={tr('Blocked people')} onPress={() => router.push('/safety/blocked')} />
          </Group>
          <SectionTitle title={tr('Learn more')} />
          <Group>
            <Row first icon="star" label={tr('How privacy works')} onPress={go('howPrivacy')} />
            <Row icon="eye" label={tr('Preview what others can see')} onPress={() => router.push('/safety/visibility')} />
          </Group>
        </>
      ),
    },
    fields: {
      kicker: 'PRIVACY', title: tr('Public profile fields'),
      intro: tr('Choose what appears on your profile. Your first name is always shown so people can recognise you at a Plan.'),
      body: (
        <>
          <Group style={{ marginTop: 16 }}>
            <ToggleRow first label={tr('Age range')} sub={tr('Shown as {v}', { v: me.ageRange ?? tr('your age range') })} value={p.showAge} onChange={toggle('showAge', tr('Age range'))} />
            <ToggleRow label={tr('Connection intent')} sub={tr('Optional. Dating is never required.')} value={p.showIntent} onChange={toggle('showIntent', tr('Connection intent'))} />
            <ToggleRow label={tr('Interests')} sub={me.interests.join(', ') || tr('None added')} value={p.showInterests} onChange={toggle('showInterests', tr('Interests'))} />
            <ToggleRow label={tr('Plans you’ve joined')} sub={tr('Only Plans that are themselves discoverable')} value={p.showPlans} onChange={toggle('showPlans', tr('Plans you’ve joined'))} />
            <Row icon="map-pin" label={tr('Approximate area')} sub={tr('Managed in Location')} value={area} onPress={go('location')} />
          </Group>
          <Button label={tr('Preview your profile')} kind="secondary" onPress={() => router.push('/me')} style={{ marginTop: 16 }} />
        </>
      ),
    },
    location: {
      kicker: 'PRIVACY', title: tr('Location'),
      intro: tr('We use approximate location to help you discover relevant Plans without showing your exact location.'),
      body: (
        <>
          <Group style={{ marginTop: 16 }}>
            <Row first icon="eye" label={tr('People see')} value={p.showArea ? area : tr('Hidden')} />
            <ToggleRow label={tr('Show approximate area')} sub={tr('On your profile and person cards')} value={p.showArea} onChange={toggle('showArea', tr('Approximate area'))} />
            <Row icon="map-pin" label={tr('Area detail')} value={shortChoice('areaLevel', p)} onPress={choice('areaLevel')} />
          </Group>
          <SectionTitle title={tr('Never shown')} />
          <Group>
            <Row first icon="lock" label={tr('Exact home address')} value={tr('Never shown')} />
            <Row icon="lock" label={tr('Exact coordinates')} value={tr('Never shown')} />
            <Row icon="lock" label={tr('Live location')} value={tr('Never shared')} />
          </Group>
          <SectionTitle title={tr('Plans')} />
          <Group><Row first icon="calendar" label={tr('Plan location')} value={shortChoice('planLocation', p)} onPress={choice('planLocation')} /></Group>
          <T variant="small" style={{ marginTop: 6 }}>{tr('Meeting points are always public places. Exact venues are only shown when a Plan needs one.')}</T>
        </>
      ),
    },
    discover: {
      kicker: 'PRIVACY', title: tr('Who can discover me'),
      intro: tr('Choose where your profile can appear. Turning these off doesn’t remove you from Plans you’ve joined.'),
      body: (
        <Group style={{ marginTop: 16 }}>
          <ToggleRow first label={tr('People discovery')} sub={tr('Appear in “People around your plans” for nearby Plans.')} value={p.discoverPeople} onChange={toggle('discoverPeople', tr('People discovery'))} />
          <ToggleRow label={tr('Plan participant lists')} sub={tr('Show to people viewing a Plan you joined. Participants in the same Plan always see you.')} value={p.discoverParticipants} onChange={toggle('discoverParticipants', tr('Plan participant lists'))} />
          <ToggleRow label={tr('Same destination')} sub={tr('Appear to people going to the same place on similar dates.')} value={p.discoverDestination} onChange={toggle('discoverDestination', tr('Same destination'))} />
          <ToggleRow label={tr('Search results')} sub={tr('Appear when people search by name or interest.')} value={p.discoverSearch} onChange={toggle('discoverSearch', tr('Search results'))} />
        </Group>
      ),
    },
    howPrivacy: {
      kicker: 'PRIVACY', title: tr('How privacy works'),
      intro: tr('People discover each other through shared Plans and context, not through access to private personal information.'),
      body: (
        <>
          <Group style={{ marginTop: 16 }}>
            <Row first icon="map-pin" label={tr('Approximate location')} sub={tr('An area like “Indiranagar area”. Never your address or live location.')} />
            <Row icon="user" label={tr('Public profile fields')} sub={tr('You choose which appear. Contact details are never public.')} />
            <Row icon="calendar" label={tr('Plan visibility')} sub={tr('Discoverable, shared-context only or private — per Plan.')} />
            <Row icon="users" label={tr('Connection controls')} sub={tr('Choose who can send you requests. Every request shows its shared context.')} />
            <Row icon="message-circle" label={tr('Messaging controls')} sub={tr('Choose who can message you. Blocking always wins.')} />
          </Group>
          <Button label={tr('Open privacy settings')} onPress={go('privacy')} style={{ marginTop: 16 }} />
        </>
      ),
    },
    security: {
      kicker: 'SETTINGS', title: tr('Security'), intro: tr('Protect your account and manage where you’re signed in.'),
      body: (
        <>
          <SectionTitle title={tr('Login & authentication')} />
          <Group>
            <Row first icon="lock" label={tr('Sign-in method')} sub={tr('One-time code to your verified phone or email')} value={me.maskedPhone ?? me.maskedEmail ?? ''} />
            <Row icon="key" label={tr('Password')} sub={tr('Backup sign-in when a code isn’t available · {v}', { v: me.hasPassword ? (me.passwordChangedAt ? tr('Changed {when}', { when: relativeTime(me.passwordChangedAt) }) : tr('Set')) : tr('Not set') })} onPress={() => router.push('/settings/password')} />
          </Group>
          <SectionTitle title={tr('Sessions')} />
          <Group><Row first icon="smartphone" label={tr('Active sessions')} onPress={() => router.push('/settings/sessions')} /></Group>
          <SectionTitle title={tr('Security activity')} />
          <Group><Row first icon="clock" label={tr('Recent security activity')} onPress={() => router.push('/settings/secActivity')} /></Group>
          <SectionTitle title={tr('Account protection')} />
          <Group><Row first icon="shield" label={tr('Account recovery')} sub={tr('Phone and email on file')} onPress={go('recovery')} /></Group>
        </>
      ),
    },
    recovery: {
      kicker: 'SECURITY', title: tr('Account recovery'), intro: tr('Used to get back into your account if you lose access. Never shown on your profile.'),
      body: (
        <Group style={{ marginTop: 16 }}>
          <Row first icon="lock" label={tr('Phone')} sub={me.signals.includes('PHONE') ? tr('Verified') : tr('Not verified')} value={me.maskedPhone ?? tr('Not added')} tag={tr('Private')} tagTone="neutral" />
          <Row icon="message-circle" label={tr('Email')} sub={me.signals.includes('EMAIL') ? tr('Verified') : tr('Not verified')} value={me.maskedEmail ?? tr('Not added')} tag={tr('Private')} tagTone="neutral" />
          <Row icon="settings" label={tr('Change these')} sub={tr('In Account information')} onPress={go('account')} />
        </Group>
      ),
    },
    lifecycle: {
      kicker: 'SETTINGS', title: tr('Deactivate or delete'), intro: tr('Two different choices. Take a break, or leave permanently.'),
      body: (
        <>
          <SectionTitle title={tr('Temporary')} />
          <Group><Row first icon="lock" label={tr('Deactivate account')} sub={tr('Hide your profile and Plans. Come back any time by signing in.')} onPress={go('deactivate')} /></Group>
          <SectionTitle title={tr('Permanent')} danger />
          <Group danger><Row first icon="trash-2" danger label={tr('Delete account')} sub={tr('Remove your profile and account. This can’t be easily undone.')} onPress={go('delete')} /></Group>
          <Group style={{ marginTop: 16 }}><Row first icon="star" label={tr('What happens to my content?')} onPress={go('content')} /></Group>
        </>
      ),
    },
    deactivate: {
      kicker: tr('ACCOUNT LIFECYCLE'), title: tr('Deactivate your account?'), intro: tr('Your profile and discovery presence will be hidden while your account is deactivated.'),
      body: (
        <>
          <SectionTitle title={tr('While deactivated')} />
          <Group>
            <Row first icon="eye" label={tr('Profile hidden')} sub={tr('People can’t open your profile.')} />
            <Row icon="search" label={tr('Not discoverable')} sub={tr('You won’t appear in people or Plan discovery.')} />
            <Row icon="users" label={tr('No new requests or messages')} sub={tr('Existing connections are paused, not removed.')} />
            <Row icon="calendar" label={tr('Your Plans')} sub={tr('Upcoming Plans you created are hidden from discovery.')} />
            <Row icon="check" label={tr('Your data is kept')} sub={tr('Sign in again to reactivate.')} />
          </Group>
          <View style={{ gap: 8, marginTop: 16 }}>
            {/* Equal weight: leaving shouldn’t be harder to find than staying. */}
            <Button label={tr('Deactivate account')} kind="secondary" onPress={() => setConfirm('deactivate')} />
            <Button label={tr('Keep account')} kind="secondary" onPress={() => router.back()} />
          </View>
        </>
      ),
    },
    delete: {
      kicker: tr('ACCOUNT LIFECYCLE'), title: tr('Delete your account?'), intro: tr('Deleting your account is permanent after a short grace period.'),
      body: (
        <>
          <SectionTitle title={tr('What happens')} />
          <Group>
            <Row first icon="user" label={tr('Profile removed')} sub={tr('Your profile and discovery presence are removed.')} />
            <Row icon="users" label={tr('Connections removed')} sub={tr('People aren’t told why.')} />
            <Row icon="calendar" label={tr('Plans you created')} sub={tr('Upcoming Plans are cancelled and participants are told.')} />
            <Row icon="message-circle" label={tr('Messages and groups')} sub={tr('Shown as from “Deleted account”, handled under our retention policy.')} />
            <Row icon="lock" label={tr('Account data')} sub={tr('Deleted after the grace period under our data policy.')} />
          </Group>
          <Group style={{ marginTop: 16 }}>
            <Row first icon="lock" label={tr('Want a break instead?')} sub={tr('Deactivate keeps everything and hides you')} onPress={() => router.replace('/settings/deactivate')} />
            <Row icon="star" label={tr('What happens to my content?')} onPress={go('content')} />
          </Group>
          <View style={{ gap: 8, marginTop: 16 }}>
            <Button label={tr('Continue')} kind="dangerSolid" onPress={() => router.push('/settings/delete-confirm')} />
            <Button label={tr('Keep account')} kind="secondary" onPress={() => router.back()} />
          </View>
        </>
      ),
    },
    content: {
      kicker: tr('ACCOUNT LIFECYCLE'), title: tr('What happens to my content?'), intro: tr('A plain-language summary of what happens when you deactivate or delete.'),
      body: (
        <Group style={{ marginTop: 16 }}>
          <Row first icon="user" label={tr('Profile')} sub={tr('Deactivate: hidden. Delete: removed.')} />
          <Row icon="calendar" label={tr('Plans you created')} sub={tr('Deactivate: hidden from discovery. Delete: upcoming Plans are cancelled and participants told.')} />
          <Row icon="calendar" label={tr('Plans you joined')} sub={tr('Delete: you leave them. Others see “A participant left”.')} />
          <Row icon="users" label={tr('Connections')} sub={tr('Deactivate: paused. Delete: removed. People aren’t told why.')} />
          <Row icon="message-circle" label={tr('Messages')} sub={tr('Deactivate: kept. Delete: shown as from “Deleted account”.')} />
          <Row icon="users" label={tr('Plan Groups')} sub={tr('Delete: you leave every group.')} />
          <Row icon="flag" label={tr('Reports you made')} sub={tr('May be kept to protect others, without your profile.')} />
          <Row icon="shield" label={tr('Verification')} sub={tr('Delete: verification results are deleted.')} />
        </Group>
      ),
    },
    restricted: {
      kicker: 'ACCOUNT', title: tr('Some features are limited'), intro: tr('Your account currently has limited access after a review under our community guidelines.'),
      foot: tr('We don’t share review details here. If you think this is a mistake, contact support.'),
      body: (
        <>
          <Group style={{ marginTop: 16 }}>
            <Row first icon="users" label={tr('New connection requests')} value={tr('Paused')} />
            <Row icon="message-circle" label={tr('Messaging people you’re not connected with')} value={tr('Paused')} />
            <Row icon="calendar" label={tr('Creating Plans')} value={tr('Paused')} />
            <Row icon="check" label={tr('Plans you’ve joined, existing chats, settings')} value={tr('Available')} />
          </Group>
          <Button label={tr('Contact support')} kind="secondary" onPress={() => router.push('/help')} style={{ marginTop: 16 }} />
        </>
      ),
    },
  };

  const pg = pages[page ?? ''];
  if (!pg) return <Screen><Header /><StateBlock icon="eye-off" tone="neutral" title={tr('This page isn’t available')} actions={[{ label: tr('Back'), onPress: () => router.back() }]} /></Screen>;

  return (
    <Screen>
      <Header kicker={pg.kicker} title={pg.title} />
      <SaveErrorBanner error={saveError} />
      {pg.intro ? <T variant="body">{pg.intro}</T> : null}
      {pg.body}
      {pg.foot ? <T variant="small" style={{ marginTop: 14 }}>{pg.foot}</T> : null}
      <ConfirmDialog
        visible={confirm === 'deactivate'}
        onClose={() => setConfirm(null)}
        title={tr('Confirm deactivation')}
        body={tr('Your profile will no longer appear, people won’t be able to discover you, and your upcoming Plans will be hidden. Sign in any time to come back.')}
        okLabel={tr('Confirm deactivation')}
        okKind="ink"
        icon="lock"
        tone="neutral"
        onConfirm={async () => setUser(await meApi.deactivate())}
      />
    </Screen>
  );
}
