import { router } from 'expo-router';
import { useState } from 'react';
import { Text, View } from 'react-native';
import { ApiError, organizersApi, type OrganizerType } from '@/api';
import { Banner, Button, Field, Header, KeyValue, RadioGroup, Screen, StateBlock, StepBars, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const TITLES = ['Organizer type', 'About you', 'Your verification', 'Review'];
const TYPES: { value: OrganizerType; label: string; sub: string }[] = [
  { value: 'INDIVIDUAL', label: 'Individual', sub: 'A person organizing activities' },
  { value: 'COMMUNITY', label: 'Community', sub: 'You run a recurring community or group' },
  { value: 'ORGANIZATION', label: 'Organization', sub: 'You represent a registered organization' },
  { value: 'OFFICIAL', label: 'Official event organizer', sub: 'You’re authorised to represent a specific event' },
];

export default function OrganizerSetup() {
  useLanguage();
  const me = useMe();
  const { refreshUser } = useAuth();
  const [step, setStep] = useState(1);
  const [type, setType] = useState<OrganizerType | null>(null);
  const [name, setName] = useState('');
  const [about, setAbout] = useState('');
  const [area, setArea] = useState(me.city ?? '');
  const [site, setSite] = useState('');
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const needsSite = type === 'ORGANIZATION' || type === 'OFFICIAL' || type === 'COMMUNITY';
  const needsEmail = type === 'ORGANIZATION' || type === 'OFFICIAL';
  const hasIdentity = me.signals.includes('IDENTITY');
  const hasPhone = me.signals.includes('PHONE');

  const next = async () => {
    setError(null);
    if (step === 1 && !type) return setError(tr('Choose what you organise.'));
    if (step === 2) {
      if (name.trim().length < 3) return setError(tr('Add your organizer name.'));
      if (about.trim().length < 20) return setError(tr('Tell people what you organise (at least 20 characters).'));
      if (needsSite && !/^(https?:\/\/)?[\w-]+(\.[\w-]+)+/.test(site.trim())) return setError(tr('Add a website or public page.'));
      if (needsEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return setError(tr('Add an official contact email.'));
    }
    if (step === 3 && !hasPhone) return setError(tr('Verify your phone first — it’s required for organizers.'));
    if (step < 4) return setStep(step + 1);
    setBusy(true);
    try {
      await organizersApi.apply({ type: type!, name: name.trim(), about: about.trim(), area: area.trim(), website: site.trim() || undefined, contactEmail: email.trim() || undefined });
      await refreshUser();
      setSubmitted(true);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t submit. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  if (submitted) {
    return (
      <Screen>
        <Header kicker={tr('BECOME AN ORGANIZER')} title={tr('Submitted')} />
        <StateBlock icon="clock" tone="blue" title={tr('Organizer verification submitted')} body={tr('We’ll review your details, usually within 1–2 working days, and notify you. You can keep using Plans as normal.')}
          actions={[{ label: tr('View status'), onPress: () => router.replace('/verify/organizer') }, { label: tr('Done'), kind: 'secondary', onPress: () => router.back() }]} />
      </Screen>
    );
  }

  const check = (ok: boolean, label: string, sub: string, fix?: () => void) => (
    <View key={label} style={{ flexDirection: 'row', gap: 12, padding: 14, backgroundColor: '#fff', borderRadius: 16, borderWidth: 1, borderColor: colors.line }}>
      <Text style={{ fontFamily: fonts.bodyBold, color: ok ? colors.brand : colors.inkSoft, fontSize: 16 }}>{ok ? '✓' : '○'}</Text>
      <View style={{ flex: 1 }}>
        <T variant="bodyStrong">{label}</T>
        <T variant="small">{sub}</T>
      </View>
      {!ok && fix ? <Button label={tr('Verify')} compact kind="secondary" onPress={fix} /> : null}
    </View>
  );

  return (
    <Screen edges={['top', 'bottom']} footer={<View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.line }}><Button label={step === 4 ? tr('Submit for verification') : tr('Continue')} loading={busy} onPress={next} /></View>}>
      <Header kicker={tr('BECOME AN ORGANIZER')} title={tr(TITLES[step - 1])} onBack={() => (step > 1 ? setStep(step - 1) : router.back())} />
      <View style={{ marginHorizontal: -16 }}><StepBars total={4} current={step} /></View>
      <T variant="caption" style={{ marginBottom: 12 }}>{tr('Step {step} of 4', { step })}</T>

      {step === 1 ? (
        <>
          <T variant="body" style={{ marginBottom: 12 }}>{tr('Choose what you organise. You keep one account — organizer tools are added to it.')}</T>
          <RadioGroup label={tr('Organizer type')} options={TYPES.map((o) => ({ ...o, label: tr(o.label), sub: tr(o.sub) }))} value={type} onChange={setType} />
        </>
      ) : null}
      {step === 2 ? (
        <>
          <Field label={type === 'INDIVIDUAL' ? tr('Organizer name') : tr('Organisation name')} value={name} onChangeText={setName} placeholder={tr('Ananya’s Photo Walks')} />
          <Field label={tr('About')} value={about} onChangeText={setAbout} multiline maxLength={600} placeholder={tr('What you organise and who it’s for')} />
          <Field label={tr('Area')} value={area} onChangeText={setArea} placeholder={tr('Bengaluru')} />
          {needsSite ? <Field label={type === 'COMMUNITY' ? tr('Website or public page') : tr('Official website')} value={site} onChangeText={setSite} autoCapitalize="none" keyboardType="url" placeholder={tr('https://')} /> : null}
          {needsEmail ? <Field label={tr('Official contact email')} value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" placeholder={tr('hello@yourorg.com')} hint={tr('Only the domain is checked. This email isn’t shown publicly.')} /> : null}
        </>
      ) : null}
      {step === 3 ? (
        <>
          <T variant="body" style={{ marginBottom: 12 }}>{tr('These come from your Verification Center. Organizer verification is separate from your personal signals.')}</T>
          <View style={{ gap: 8 }}>
            {check(hasPhone, tr('Phone verified'), tr('Required for all organizers'), () => router.push('/verify/phone'))}
            {check(hasIdentity, tr('Identity verified'), type === 'OFFICIAL' || type === 'ORGANIZATION' ? tr('Strongly recommended for organisations') : tr('Optional'), () => router.push('/verify/identity'))}
            {check(!!site || !needsSite, tr('Public presence'), needsSite ? tr('We check your website or public page') : tr('Not required for individuals'))}
          </View>
        </>
      ) : null}
      {step === 4 ? (
        <>
          <T variant="body" style={{ marginBottom: 12 }}>{tr('Check your details. We’ll review them before Organizer verified appears.')}</T>
          <KeyValue rows={[
            { k: tr('Type'), v: tr(TYPES.find((t) => t.value === type)?.label ?? '') },
            { k: tr('Name'), v: name },
            { k: tr('Area'), v: area },
            ...(site ? [{ k: tr('Website'), v: site }] : []),
            ...(email ? [{ k: tr('Contact email'), v: tr('{v} · not public', { v: email.split('@')[1] ? `••••@${email.split('@')[1]}` : '' }) }] : []),
          ]} />
          <Button label={tr('Edit details')} kind="text" onPress={() => setStep(2)} style={{ alignSelf: 'flex-start' }} />
          <T variant="small">{tr('It doesn’t verify every attendee, or guarantee how an event goes.')}</T>
        </>
      ) : null}
      {error ? <View style={{ marginTop: 12 }}><Banner icon="alert-circle" tone="bad" title={error} /></View> : null}
    </Screen>
  );
}
