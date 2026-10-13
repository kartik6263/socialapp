import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { discoverApi, type PersonCard } from '@/api';
import { Appear } from '@/components/motion';
import { PlanCard } from '@/components/PlanCard';
import { TrustSignals } from '@/components/TrustSignals';
import {
  Avatar, Banner, Button, Card, ErrorBlock, FilterPills, Headline, Icon, IconButton, Logo, Screen, Skeleton, StateBlock, T, UserAvatar,
} from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { useFocusData } from '@/hooks/useAsync';
import { colors, fonts, glass } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

export default function Discover() {
  useLanguage();
  const me = useMe();
  const { refreshUser } = useAuth();
  const [filter, setFilter] = useState<'all' | 'official'>('all');
  const { data, error, loading, refreshing, refresh } = useFocusData(async () => {
    void refreshUser().catch(() => undefined); // keeps bell / chat badges fresh
    return discoverApi.home(filter);
  }, [filter]);

  const unread = me.unreadNotifications;
  const badge = unread > 9 ? '9+' : unread > 0 ? String(unread) : null;

  return (
    <Screen padded={false} refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.brand} />}>
      <View style={styles.header}>
        <Logo />
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <IconButton name="bell" filled label={badge ? tr('Notifications, {badge} unread', { badge }) : tr('Notifications')} badge={badge} onPress={() => router.push('/notifications')} />
          <Pressable onPress={() => router.push('/me')} accessibilityRole="button" accessibilityLabel={tr('Your profile')}>
            <Avatar name={me.displayName} photoUrl={me.photoUrl} id={me.id} size={40} tone="violet" />
          </Pressable>
        </View>
      </View>

      <View style={{ paddingHorizontal: 16, paddingTop: 20 }}>
        {me.accountStatus === 'RESTRICTED' ? (
          <Pressable onPress={() => router.push('/settings/restricted')} style={{ marginBottom: 16 }}>
            <Banner icon="lock" tone="warn" title={tr('Some features are limited on your account')} body={tr('See what’s affected')} />
          </Pressable>
        ) : null}

        <T variant="kicker">{tr('PLANS FIRST · PEOPLE WITH CONTEXT')}</T>
        <View style={{ marginTop: 8, marginBottom: 8 }}>
          <Headline text={tr('Discover who else is ')} accent={tr('doing it.')} />
        </View>
        <T variant="body">{tr('Relevant plans and people around your selected area, schedule and interests.')}</T>

        <Pressable onPress={() => router.push('/search')} style={styles.search} accessibilityRole="search" accessibilityLabel={tr('Search plans, people, destinations')}>
          <Icon name="search" size={18} color={colors.inkSoft} />
          <Text style={styles.searchText}>{tr('Search plans, people, destinations')}</Text>
        </Pressable>

        <View style={styles.sectionHead}>
          <T variant="kicker">{tr('NEAR YOUR SELECTED AREA')}</T>
          <T variant="heading" style={{ fontSize: 20, marginTop: 4 }}>{tr('Nearby plans')}</T>
        </View>
        <FilterPills options={[{ key: 'all', label: tr('All plans') }, { key: 'official', label: tr('Official events') }]} value={filter} onChange={setFilter} />

        {loading ? <Skeleton /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : data ? (
          <>
            {data.organizerNearby && filter === 'official' ? (
              <Card onPress={() => router.push(`/organizer/${data.organizerNearby!.id}`)} style={styles.org}>
                <Avatar name={data.organizerNearby.name} id={data.organizerNearby.id} size={44} tone="mint" />
                <View style={{ flex: 1 }}>
                  <T variant="kicker" style={{ color: colors.inkSoft }}>{tr('ORGANIZER NEAR YOU')}</T>
                  <T variant="bodyStrong">{data.organizerNearby.name}</T>
                  <T variant="small">
                    {data.organizerNearby.signals.includes('ORGANIZER') ? tr('Organizer verified · ') : ''}
                    {data.organizerNearby.upcomingCount} {tr('upcoming events')}
                  </T>
                </View>
                <Icon name="arrow-right" size={16} color={colors.brand} />
              </Card>
            ) : null}

            <View style={{ gap: 14, marginTop: 14 }}>
              {data.plans.length ? (
                // Cards settle in one after another on arrival, so the eye follows the list.
                data.plans.map((p, i) => <Appear key={p.id} delay={Math.min(i, 5) * 70}><PlanCard plan={p} onPress={() => router.push(`/plan/${p.id}`)} /></Appear>)
              ) : (
                <StateBlock
                  icon="calendar"
                  title={tr('Nothing nearby yet')}
                  body={tr('Create a Plan and let people around you discover it.')}
                  actions={[{ label: tr('Create a Plan'), onPress: () => router.push('/plan/new') }]}
                />
              )}
            </View>

            <View style={styles.sectionHead}>
              <T variant="kicker">{tr('PEOPLE WITH A REAL-WORLD REASON')}</T>
              <T variant="heading" style={{ fontSize: 20, marginTop: 4 }}>{tr('People around your plans')}</T>
            </View>
            {data.hiddenFromPeople ? (
              <Pressable onPress={() => router.push('/settings/discover')} style={{ marginBottom: 12 }}>
                <Banner icon="eye-off" tone="neutral" title={tr('You’re hidden from People discovery. You can still see others.')} action={tr('Change')} onAction={() => router.push('/settings/discover')} />
              </Pressable>
            ) : null}
            <View style={{ gap: 12 }}>
              {data.people.length ? (
                data.people.map((p, i) => <Appear key={p.user.id} delay={Math.min(i, 5) * 70}><PersonTile person={p} /></Appear>)
              ) : (
                <StateBlock icon="users" title={tr('No matching people yet')} body={tr('Join or create a Plan — people doing the same thing will appear here.')} />
              )}
            </View>
            <View style={styles.finite}>
              <Icon name="check" size={13} color={colors.brand} />
              <T variant="small">{tr('You’re up to date. Discovery is intentionally finite.')}</T>
            </View>
          </>
        ) : null}
      </View>
    </Screen>
  );
}

function PersonTile({ person }: { person: PersonCard }) {
  useLanguage();
  const { user } = person;
  const open = () => router.push(`/user/${user.id}`);
  return (
    <Card style={{ gap: 9 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        <UserAvatar user={user} size={44} />
        <View style={{ flex: 1 }}>
          <T variant="bodyStrong">{user.displayName}</T>
          {user.area ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 }}>
              <Icon name="map-pin" size={11} color={colors.inkSoft} />
              <T variant="caption">{user.area} {tr('· approximate')}</T>
            </View>
          ) : null}
        </View>
      </View>
      <TrustSignals signals={user.signals} name={user.displayName.split(' ')[0]} unavailable={user.signalsUnavailable} compact />
      {person.bio ? <T variant="small" numberOfLines={2}>{person.bio}</T> : null}
      <View style={styles.context}>
        <Icon name="star" size={11} color={colors.ink} />
        <Text style={styles.contextText}>{person.context}</Text>
      </View>
      {person.sharedInterests.length ? (
        <T variant="small">{trRich('Shared interests: {list}', { list: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{person.sharedInterests.join(' · ')}</Text> })}</T>
      ) : null}
      <Button label={tr('View profile')} kind="secondary" compact iconRight="arrow-right" onPress={open} style={{ alignSelf: 'flex-start' }}
        accessibilityLabel={tr('View {displayName} profile', { displayName: user.displayName })} />
    </Card>
  );
}

const styles = StyleSheet.create({
  header: { height: 64, paddingHorizontal: 16, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  search: { flexDirection: 'row', alignItems: 'center', gap: 10, height: 52, borderRadius: 18, borderWidth: 1, borderColor: glass.border, backgroundColor: glass.fillStrong, paddingHorizontal: 16, marginTop: 18, ...glass.shadow, shadowOpacity: 0.07 },
  searchText: { fontFamily: fonts.body, fontSize: 14, color: colors.inkSoft },
  sectionHead: { marginTop: 26, marginBottom: 12 },
  org: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 14 },
  context: { flexDirection: 'row', alignItems: 'center', gap: 5, alignSelf: 'flex-start', backgroundColor: colors.lime, borderRadius: 999, paddingHorizontal: 9, paddingVertical: 5 },
  contextText: { fontFamily: fonts.bodyBold, fontSize: 11, color: colors.ink },
  finite: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, paddingVertical: 24 },
});
