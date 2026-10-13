import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { View, type TextInput } from 'react-native';
import { ApiError, meApi, privacyApi } from '@/api';
import { ConsentChecks, type ConsentState } from '@/components/ConsentChecks';
import { Avatar, Button, Field, Header, Logo, Screen, T } from '@/components/ui';
import { useMe, useAuth } from '@/context/AuthContext';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function OnboardingProfile() {
  useLanguage();
  const me = useMe();
  const { setUser } = useAuth();
  const [name, setName] = useState(me.displayName === 'New member' ? '' : me.displayName);
  const [birthYear, setBirthYear] = useState('');
  const [area, setArea] = useState(me.area ?? '');
  const [city, setCity] = useState(me.city ?? '');
  const [bio, setBio] = useState(me.bio ?? '');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  // Keyboard “Next” moves through the form in order.
  const rName = useRef<TextInput>(null);
  const rYear = useRef<TextInput>(null);
  const rArea = useRef<TextInput>(null);
  const rCity = useRef<TextInput>(null);
  const rBio = useRef<TextInput>(null);
  // Accounts created from the “Sign in” path haven’t agreed to the Terms yet: ask here, before any profile data is saved.
  const [needsConsent, setNeedsConsent] = useState(false);
  const [consent, setConsent] = useState<ConsentState>({ terms: false, adult: false });
  const [consentError, setConsentError] = useState(false);
  useEffect(() => {
    privacyApi.consents().then((c) => setNeedsConsent(!c.history.some((h) => h.kind === 'TERMS' && h.granted))).catch(() => undefined);
  }, []);

  const save = async () => {
    const e: Record<string, string> = {};
    const year = Number(birthYear);
    const age = new Date().getFullYear() - year;
    if (name.trim().length < 2) e.name = tr('Enter at least 2 characters.');
    if (birthYear.length === 4 && !Number.isNaN(year) && age < 18) {
      // Under 18: don't save the birth year or anything else; explain and offer to erase the account.
      router.replace('/onboarding/underage');
      return;
    }
    if (!birthYear || Number.isNaN(year) || age > 100) e.birthYear = tr('Enter your birth year, like 2001.');
    if (needsConsent && !(consent.terms && consent.adult)) {
      setConsentError(true);
      e.consent = 'required';
    }
    if (!area.trim()) e.area = tr('Add an approximate area, like a neighbourhood.');
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    try {
      if (needsConsent) {
        await privacyApi.recordSignup();
        setNeedsConsent(false);
      }
      setUser(await meApi.update({
        displayName: name.trim(), birthYear: year, area: area.trim(), city: city.trim(), bio: bio.trim(),
        interests: me.interests, languages: me.languages.length ? me.languages : ['English'], intents: me.intents,
      }));
      router.push('/onboarding/interests');
    } catch (err) {
      if (err instanceof ApiError && err.code === 'UNDERAGE') {
        router.replace('/onboarding/underage');
        return;
      }
      setErrors(err instanceof ApiError && err.fields ? err.fields : { form: err instanceof ApiError ? err.message : tr('Couldn’t save.') });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Header hideBack right={<T variant="caption">{tr('1 of 2')}</T>} />
      <View style={{ position: 'absolute', top: 18, alignSelf: 'center' }}><Logo size={16} /></View>
      <T variant="kicker">{tr('YOUR ESSENTIALS')}</T>
      <T variant="display" style={{ marginTop: 8, fontSize: 28 }}>{tr('Enough to make a good introduction.')}</T>
      <T variant="body" style={{ marginTop: 6, marginBottom: 18 }}>{tr('No long questionnaire. You can change everything later.')}</T>

      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <Avatar name={name || '?'} id={me.id} size={56} />
        <View style={{ flex: 1 }}>
          <T variant="bodyStrong">{tr('Your initials stand in for a photo')}</T>
          <T variant="small">{tr('People recognise you at a Plan by your first name.')}</T>
        </View>
      </View>

      <Field label={tr('Name')} value={name} onChangeText={setName} autoComplete="name" placeholder={tr('Ananya Kapoor')} ref={rName} returnKeyType="next" submitBehavior="submit" onSubmitEditing={() => rYear.current?.focus()} error={errors.name ?? errors.displayName} />
      <Field label={tr('Birth year')} value={birthYear} onChangeText={(t) => setBirthYear(t.replace(/\D/g, '').slice(0, 4))} keyboardType="number-pad" placeholder="2002" ref={rYear} returnKeyType="next" submitBehavior="submit" onSubmitEditing={() => rArea.current?.focus()} hint={tr('Plans is 18+. Only your age range (like 22–25) is shown — never your birth year.')} error={errors.birthYear} />
      <Field label={tr('Area')} value={area} onChangeText={setArea} placeholder={tr('Indiranagar')} ref={rArea} returnKeyType="next" submitBehavior="submit" onSubmitEditing={() => rCity.current?.focus()} hint={tr('Never your exact home address.')} error={errors.area} />
      <Field label={tr('City')} optional value={city} onChangeText={setCity} placeholder={tr('Bengaluru')} hint={tr('Helps show Plans near you.')} ref={rCity} returnKeyType="next" submitBehavior="submit" onSubmitEditing={() => rBio.current?.focus()} />
      <Field ref={rBio} label={tr('Short bio')} optional value={bio} onChangeText={setBio} multiline maxLength={300} placeholder={tr('Product designer, weekend trekker and live music regular.')} />
      {needsConsent ? <ConsentChecks value={consent} onChange={(v) => { setConsent(v); setConsentError(false); }} error={consentError} /> : null}
      {errors.form ? <T variant="small" style={{ color: colors.dangerText, marginBottom: 8 }} accessibilityRole="alert">{errors.form}</T> : null}
      <Button label={tr('Continue')} iconRight="arrow-right" loading={busy} onPress={save} />
    </Screen>
  );
}
