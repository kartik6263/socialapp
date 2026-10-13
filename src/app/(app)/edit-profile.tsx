import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { ApiError, INTENTS, INTERESTS, meApi, type Intent } from '@/api';
import { Banner, Button, Chip, Field, Group, Header, Row, Screen, SectionTitle, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { tr, useLanguage } from '@/i18n';

const LANGS = ['English', 'Hindi', 'Kannada', 'Tamil', 'Telugu', 'Marathi', 'Bengali', 'Malayalam'];

export default function EditProfile() {
  useLanguage();
  const me = useMe();
  const { setUser } = useAuth();
  const toast = useToast();
  const [area, setArea] = useState(me.area ?? '');
  const [city, setCity] = useState(me.city ?? '');
  const [bio, setBio] = useState(me.bio ?? '');
  const [interests, setInterests] = useState(me.interests);
  const [languages, setLanguages] = useState(me.languages);
  const [intents, setIntents] = useState<Intent[]>(me.intents);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const toggle = <V,>(list: V[], v: V) => (list.includes(v) ? list.filter((x) => x !== v) : [...list, v]);

  const save = async () => {
    if (!area.trim()) return setError(tr('Add an approximate area.'));
    setBusy(true);
    setError(null);
    try {
      setUser(await meApi.update({ displayName: me.displayName, area: area.trim(), city: city.trim(), bio: bio.trim(), photoUrl: me.photoUrl, interests, languages, intents }));
      toast(tr('Profile updated'));
      router.back();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Header kicker={tr('YOUR PROFILE')} title={tr('Edit profile')} />
      <Group>
        <Row first icon="user" label={tr('Name')} value={me.displayName} onPress={() => router.push('/settings/name')} />
        <Row icon="clock" label={tr('Age range')} value={me.ageRange ?? '—'} sub={tr('From your birth year')} />
      </Group>
      <View style={{ height: 16 }} />
      <Field label={tr('Area')} value={area} onChangeText={setArea} hint={tr('Never your exact home address.')} />
      <Field label={tr('City')} value={city} onChangeText={setCity} />
      <Field label={tr('Bio')} optional value={bio} onChangeText={setBio} multiline maxLength={300} hint={`${bio.length}/300`} />

      <SectionTitle title={tr('Interests')} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {INTERESTS.map((i) => <Chip key={i} label={i} selected={interests.includes(i)} onPress={() => setInterests(toggle(interests, i))} />)}
      </View>
      <SectionTitle title={tr('Languages')} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {LANGS.map((l) => <Chip key={l} label={l} selected={languages.includes(l)} onPress={() => setLanguages(toggle(languages, l))} />)}
      </View>
      <SectionTitle title={tr('Open to (optional)')} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {INTENTS.map((i) => <Chip key={i.value} label={i.label} selected={intents.includes(i.value)} onPress={() => setIntents(toggle(intents, i.value))} />)}
      </View>
      <T variant="small" style={{ marginTop: 8 }}>{tr('Dating is optional and never required.')}</T>

      <SectionTitle title={tr('Trust')} />
      <Group><Row first icon="shield" label={tr('Verification')} onPress={() => router.push('/verify')} /></Group>

      {error ? <View style={{ marginTop: 12 }}><Banner icon="alert-circle" tone="bad" title={error} /></View> : null}
      <Button label={tr('Save profile')} loading={busy} onPress={save} style={{ marginTop: 18 }} />
    </Screen>
  );
}
