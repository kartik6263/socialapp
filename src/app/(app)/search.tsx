import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { ApiError, discoverApi, type PersonCard, type PlanSummary } from '@/api';
import { PlanRow } from '@/components/PlanCard';
import { Avatar, Chip, ErrorBlock, Group, Icon, IconButton, Screen, SectionTitle, Skeleton, StateBlock, T, goBack } from '@/components/ui';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const SUGGESTIONS = ['Goa', 'Trekking', 'Photography', 'Hackathon', 'Concert', 'Badminton', 'Networking', 'Cafés'];

export default function Search() {
  useLanguage();
  const [q, setQ] = useState('');
  const [result, setResult] = useState<{ plans: PlanSummary[]; people: PersonCard[] } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);
  const seq = useRef(0);

  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) {
      setResult(null);
      return;
    }
    const mine = ++seq.current;
    const t = setTimeout(async () => {
      setLoading(true);
      try {
        const r = await discoverApi.search(term);
        if (mine === seq.current) { setResult(r); setError(null); }
      } catch (e) {
        if (mine === seq.current) setError(e instanceof ApiError ? e : null);
      } finally {
        if (mine === seq.current) setLoading(false);
      }
    }, 300); // debounce keeps search load sane at scale
    return () => clearTimeout(t);
  }, [q]);

  return (
    <Screen>
      <View style={styles.bar}>
        <IconButton name="chevron-left" label={tr('Back')} onPress={goBack} />
        <View style={styles.input}>
          <Icon name="search" size={17} color={colors.inkSoft} />
          <TextInput value={q} onChangeText={setQ} autoFocus placeholder={tr('Search plans, people, destinations')} placeholderTextColor="#8a9893" style={styles.text} returnKeyType="search" accessibilityLabel={tr('Search')} />
          {q ? <IconButton name="x" label={tr('Clear search')} onPress={() => setQ('')} /> : null}
        </View>
      </View>

      {!result && !loading ? (
        <>
          <SectionTitle title={tr('Try')} />
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
            {SUGGESTIONS.map((s) => <Chip key={s} label={s} onPress={() => setQ(s)} />)}
          </View>
          <T variant="small" style={{ marginTop: 16 }}>{tr('Search uses your selected area — never your precise live location.')}</T>
        </>
      ) : loading && !result ? <Skeleton /> : error && !result ? <ErrorBlock error={error} onRetry={() => setQ(q + ' ')} /> : result ? (
        !result.plans.length && !result.people.length ? (
          <StateBlock icon="search" tone="neutral" title={tr('No results found')} body={tr('Try a different activity, destination, event, or keyword.')} actions={[{ label: tr('Create a Plan'), onPress: () => router.push('/plan/new') }]} />
        ) : (
          <>
            {result.plans.length ? (
              <>
                <SectionTitle title={tr('Plans')} />
                <Group>{result.plans.map((p, i) => <PlanRow key={p.id} plan={p} first={i === 0} onPress={() => router.push(`/plan/${p.id}`)} />)}</Group>
              </>
            ) : null}
            {result.people.length ? (
              <>
                <SectionTitle title={tr('People')} />
                <Group>
                  {result.people.map((p, i) => (
                    <Pressable key={p.user.id} onPress={() => router.push(`/user/${p.user.id}`)} style={[styles.person, i > 0 && { borderTopWidth: 1, borderTopColor: colors.divider }]} accessibilityRole="button">
                      <Avatar name={p.user.displayName} photoUrl={p.user.photoUrl} id={p.user.id} size={40} />
                      <View style={{ flex: 1 }}>
                        <T variant="bodyStrong">{p.user.displayName}</T>
                        <T variant="small" numberOfLines={1}>{p.context}</T>
                      </View>
                      <Icon name="chevron-right" size={16} color={colors.inkSoft} />
                    </Pressable>
                  ))}
                </Group>
              </>
            ) : null}
          </>
        )
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  bar: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingVertical: 10 },
  input: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, height: 48, borderRadius: 16, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.surface, paddingLeft: 12 },
  text: { flex: 1, fontFamily: fonts.body, fontSize: 15, color: colors.ink },
  person: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 12 },
});
