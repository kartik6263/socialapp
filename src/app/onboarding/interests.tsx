import { useState } from 'react';
import { View } from 'react-native';
import { ApiError, INTENTS, INTERESTS, analyticsApi, meApi, type Intent } from '@/api';
import { Button, Chip, Header, Note, Screen, SectionTitle, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { tr, useLanguage } from '@/i18n';

export default function OnboardingInterests() {
  useLanguage();
  const me = useMe();
  const { setUser } = useAuth();
  const [interests, setInterests] = useState<string[]>(me.interests);
  const [intents, setIntents] = useState<Intent[]>(me.intents);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const toggle = <V,>(list: V[], v: V) => (list.includes(v) ? list.filter((x) => x !== v) : [...list, v]);

  const finish = async () => {
    setBusy(true);
    setError('');
    try {
      await meApi.update({
        displayName: me.displayName, area: me.area ?? '', city: me.city ?? undefined, bio: me.bio ?? undefined,
        interests, languages: me.languages, intents,
      });
      setUser(await meApi.completeOnboarding());
      analyticsApi.track('onboarding_completed', { interests: interests.length });
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Header right={<T variant="caption">{tr('2 of 2')}</T>} />
      <T variant="kicker">{tr('PERSONALISE DISCOVERY')}</T>
      <T variant="display" style={{ marginTop: 8, fontSize: 28 }}>{tr('What would you actually show up for?')}</T>
      <T variant="body" style={{ marginTop: 6 }}>{tr('Pick a few. Plans—not profile labels—drive your experience.')}</T>

      <SectionTitle title={tr('Interests')} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {INTERESTS.map((i) => <Chip key={i} label={i} selected={interests.includes(i)} onPress={() => setInterests(toggle(interests, i))} />)}
      </View>

      <SectionTitle title={tr('Open to (optional)')} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {INTENTS.map((i) => <Chip key={i.value} label={i.label} selected={intents.includes(i.value)} onPress={() => setIntents(toggle(intents, i.value))} />)}
      </View>
      <T variant="small" style={{ marginTop: 8 }}>{tr('Dating is optional and never required. Plans is about shared real-world activities.')}</T>

      <View style={{ marginVertical: 18 }}>
        <Note icon="lock">{tr('Your choices improve discovery. They’re never used to expose private contact or location details.')}</Note>
      </View>
      {error ? <T variant="small" style={{ color: '#b94343', marginBottom: 8 }}>{error}</T> : null}
      <Button label={tr('Explore plans')} iconRight="arrow-right" loading={busy} disabled={interests.length === 0} onPress={finish} />
    </Screen>
  );
}
