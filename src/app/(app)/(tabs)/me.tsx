import { router } from 'expo-router';
import { RefreshControl, StyleSheet, View } from 'react-native';
import { TrustSignals } from '@/components/TrustSignals';
import { Avatar, Banner, Button, Chip, FilterPills, Icon, IconButton, Screen, SectionTitle, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { useFocusData } from '@/hooks/useAsync';
import { intentLabel } from '@/lib/format';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

/** "Your profile" (prototype w20.isMe): how others see you, completeness, edit + settings. */
export default function MyProfile() {
  useLanguage();
  const me = useMe();
  const { refreshUser } = useAuth();
  const { refreshing, refresh } = useFocusData(() => refreshUser());
  const p = me.privacy;
  const orgVerified = me.organizer?.status === 'VERIFIED';

  return (
    <Screen refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.brand} />}>
      <View style={styles.top}>
        <T variant="bodyStrong" style={{ fontSize: 15 }}>{tr('Your profile')}</T>
        <IconButton name="settings" label={tr('Settings')} onPress={() => router.push('/settings')} />
      </View>

      <View style={styles.hero}>
        <Avatar name={me.displayName} photoUrl={me.photoUrl} id={me.id} size={84} tone="violet" />
        <T variant="kicker" style={{ marginTop: 12 }}>
          {p.showIntent && me.intents.length ? me.intents.slice(0, 2).map(intentLabel).join(' · ').toUpperCase() : tr('INTENT HIDDEN')}
        </T>
        <T variant="title" style={{ marginTop: 4 }}>{me.displayName}{p.showAge && me.ageRange ? `, ${me.ageRange}` : ''}</T>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4, marginBottom: 10 }}>
          <Icon name="map-pin" size={12} color={colors.inkSoft} />
          <T variant="small">{p.showArea ? tr('{v} · approximate', { v: p.areaLevel === 'CITY' ? me.city ?? me.area : `${me.area}${me.city ? `, ${me.city}` : ''}` }) : tr('Location hidden')}</T>
        </View>
        <TrustSignals signals={me.signals} name="You" />
      </View>

      {me.organizer ? (
        <View style={{ marginBottom: 14 }}>
          <FilterPills
            options={[{ key: 'personal', label: tr('Personal profile') }, { key: 'org', label: tr('Organizer profile') }]}
            value="personal"
            onChange={(k) => k === 'org' && router.push(`/organizer/${me.organizer!.id}`)}
          />
        </View>
      ) : null}

      {!me.signals.length ? (
        <View style={{ marginBottom: 12 }}>
          <Banner icon="shield" tone="neutral" title={tr('No verification completed yet')} body={tr('Complete available verification steps to add trust signals to your profile.')} action={tr('Verify')} onAction={() => router.push('/verify')} />
        </View>
      ) : null}

      {me.completeness.percent < 100 ? (
        <View style={styles.complete}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <T variant="bodyStrong">{tr('Profile {percent}% complete', { percent: me.completeness.percent })}</T>
            <T variant="caption">{tr('{done} of {total}', { done: me.completeness.done, total: me.completeness.total })}</T>
          </View>
          <View style={styles.track} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: 100, now: me.completeness.percent }}>
            <View style={[styles.fill, { width: `${me.completeness.percent}%` }]} />
          </View>
          <T variant="small">{me.completeness.hint ?? ''} {tr('Completeness helps introductions — it isn’t a trust or safety measure.')}</T>
        </View>
      ) : null}

      <View style={{ flexDirection: 'row', gap: 8, marginTop: 4 }}>
        <Button label={tr('Edit profile')} icon="edit-2" kind="secondary" onPress={() => router.push('/edit-profile')} style={{ flex: 1 }} />
        <Button label={tr('Settings')} kind="secondary" onPress={() => router.push('/settings')} style={{ flex: 1 }} />
      </View>
      {!me.organizer ? (
        <Button label={tr('Become an organizer')} kind="text" icon="users" onPress={() => router.push('/organizer/setup')} style={{ marginTop: 6 }} />
      ) : !orgVerified ? (
        <Button label={tr('Organizer verification status')} kind="text" icon="clock" onPress={() => router.push('/verify/organizer')} style={{ marginTop: 6 }} />
      ) : null}

      <SectionTitle title={tr('About')} />
      <T variant="body">{me.bio || tr('Add a short bio so people know what you’re into.')}</T>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
        {me.interests.map((i) => <Chip key={i} label={i} />)}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  top: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 10 },
  hero: { alignItems: 'center', paddingVertical: 16 },
  complete: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, padding: 14, gap: 8, marginBottom: 12 },
  track: { height: 8, borderRadius: 4, backgroundColor: colors.muted, overflow: 'hidden' },
  fill: { height: 8, borderRadius: 4, backgroundColor: colors.brand },
});
