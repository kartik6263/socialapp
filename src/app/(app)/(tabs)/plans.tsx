import { router } from 'expo-router';
import { RefreshControl, View } from 'react-native';
import { plansApi, type PlanSummary } from '@/api';
import { PlanRow } from '@/components/PlanCard';
import { ErrorBlock, Group, Headline, Screen, SectionTitle, Skeleton, StateBlock, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function MyPlans() {
  useLanguage();
  const { data, error, loading, refreshing, refresh } = useFocusData(() => plansApi.mine());

  const section = (title: string, list: PlanSummary[]) =>
    list.length ? (
      <View key={title}>
        <SectionTitle title={title} />
        <Group>
          {list.map((p, i) => <PlanRow key={p.id} plan={p} first={i === 0} onPress={() => router.push(`/plan/${p.id}`)} />)}
        </Group>
      </View>
    ) : null;

  const empty = data && !data.upcoming.length && !data.hosting.length && !data.drafts.length && !data.past.length;

  return (
    <Screen refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.brand} />}>
      <View style={{ paddingTop: 20 }}>
        <T variant="kicker">{tr('YOUR CALENDAR')}</T>
        <View style={{ marginTop: 8 }}><Headline text={tr('My ')} accent={tr('plans.')} size="title" /></View>
      </View>
      {loading ? <Skeleton /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : empty ? (
        <StateBlock
          icon="calendar"
          title={tr('No plans yet')}
          body={tr('Start a Plan for something you want to do, or join one nearby.')}
          actions={[
            { label: tr('Create a Plan'), onPress: () => router.push('/plan/new') },
            { label: tr('Discover plans'), onPress: () => router.navigate('/'), kind: 'secondary' },
          ]}
        />
      ) : data ? (
        <>
          {section(tr('Hosting'), data.hosting)}
          {section(tr('Joined'), data.upcoming)}
          {section(tr('Drafts'), data.drafts)}
          {section(tr('Past'), data.past)}
        </>
      ) : null}
    </Screen>
  );
}
