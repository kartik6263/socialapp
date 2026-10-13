import { Animated, Pressable, StyleSheet, Text, View } from 'react-native';
import type { PlanSummary } from '@/api/types';
import { planDate, topSignal } from '@/lib/format';
import { colors, fonts, shadow } from '@/theme';
import { useFocusRing, usePressScale } from './motion';
import { PlanCover } from './PlanCover';
import { Avatar, Icon, PlanStatusPill, T } from './ui';
import { categoryLabel } from '@/lib/categories';
import { tr, useLanguage } from '@/i18n';

/** Home "Nearby plans" card: cover, category, Official event, why it's relevant, host. */
export function PlanCard({ plan, onPress }: { plan: PlanSummary; onPress: () => void }) {
  useLanguage();
  const sig = topSignal(plan.host.signals);
  const press = usePressScale(0.98);
  const focus = useFocusRing();
  return (
    <Pressable onPress={onPress} onPressIn={press.onPressIn} onPressOut={press.onPressOut} {...focus.handlers} accessibilityRole="button"
      accessibilityLabel={`${plan.title}, ${categoryLabel(plan.category)}, ${planDate(plan.startAt, plan.endAt)}, ${plan.area}${plan.official ? `, ${tr('Official event')}` : ''}`}>
    <Animated.View style={[styles.card, focus.ring, press.style]}>
      <View style={styles.cover}>
        <PlanCover plan={plan} iconSize={58} />
        <View style={styles.scrim} />
        <View style={styles.badges}>
          <Text style={styles.cat}>{categoryLabel(plan.category).toUpperCase()}</Text>
          {plan.official ? (
            <View style={styles.official}>
              <Icon name="check" size={11} color={colors.ink} />
              <Text style={styles.officialText}>{tr('Official event')}</Text>
            </View>
          ) : null}
        </View>
        {plan.why ? (
          <View style={styles.why}>
            <Icon name="star" size={10} color={colors.ink} />
            <Text style={styles.whyText} numberOfLines={1}>{plan.why}</Text>
          </View>
        ) : null}
      </View>
      <View style={{ padding: 14, gap: 6 }}>
        <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8 }}>
          <T variant="heading" style={{ flex: 1, fontSize: 17 }} numberOfLines={2}>{plan.title}</T>
          {plan.status !== 'ACTIVE' ? <PlanStatusPill status={plan.status} /> : null}
        </View>
        <Meta icon="calendar" text={planDate(plan.startAt, plan.endAt)} />
        <Meta icon="map-pin" text={tr('{area} · approximate', { area: plan.area })} />
        <View style={styles.host}>
          <Avatar name={plan.host.name} photoUrl={plan.host.photoUrl} id={plan.host.id} size={26} />
          <Text style={styles.hostName} numberOfLines={1}>
            {plan.host.name}
            {sig ? <Text style={styles.hostSig}> · {sig}</Text> : null}
          </Text>
        </View>
      </View>
    </Animated.View>
    </Pressable>
  );
}

/** Compact list row: organizer upcoming list, My plans, search results. */
export function PlanRow({ plan, onPress, first }: { plan: PlanSummary; onPress: () => void; first?: boolean }) {
  useLanguage();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" style={({ pressed }) => [styles.row, !first && { borderTopWidth: 1, borderTopColor: colors.divider }, pressed && { backgroundColor: colors.paper }]}>
      <View style={styles.rowIcon}><Icon name="calendar" size={17} color={colors.brand} /></View>
      <View style={{ flex: 1, gap: 2 }}>
        <T variant="bodyStrong" numberOfLines={1}>{plan.title}</T>
        <T variant="small" numberOfLines={1}>
          {planDate(plan.startAt, plan.endAt)} · {plan.area} · {tr('{n} of {limit}', { n: plan.participantCount, limit: plan.participantLimit })}
        </T>
        {plan.official ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
            <Icon name="check" size={11} color={colors.brand} />
            <T variant="caption" style={{ color: colors.brand }}>{tr('Official event')}</T>
          </View>
        ) : null}
      </View>
      {plan.status !== 'ACTIVE' ? <PlanStatusPill status={plan.status} /> : <Icon name="chevron-right" size={16} color={colors.inkSoft} />}
    </Pressable>
  );
}

function Meta({ icon, text }: { icon: 'calendar' | 'map-pin'; text: string }) {
  useLanguage();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 7 }}>
      <Icon name={icon} size={13} color={colors.inkSoft} />
      <T variant="small" numberOfLines={1} style={{ flex: 1 }}>{text}</T>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.surface, borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.9)', overflow: 'hidden', ...shadow },
  cover: { height: 138, overflow: 'hidden', backgroundColor: colors.brandDark },
  scrim: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(15,25,23,0.12)' },
  badges: { position: 'absolute', left: 12, top: 12, flexDirection: 'row', gap: 6 },
  cat: { overflow: 'hidden', backgroundColor: 'rgba(15,25,23,0.45)', color: '#fff', borderRadius: 999, paddingHorizontal: 9, paddingVertical: 5, fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 0.8 },
  official: { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: '#fff', borderRadius: 999, paddingHorizontal: 8, paddingVertical: 4 },
  officialText: { fontFamily: fonts.bodyBold, fontSize: 10, color: colors.ink },
  why: { position: 'absolute', left: 12, bottom: 12, maxWidth: '85%', flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: colors.lime, borderRadius: 999, paddingHorizontal: 9, paddingVertical: 5 },
  whyText: { fontFamily: fonts.bodyBold, fontSize: 11, color: colors.ink },
  host: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 4 },
  hostName: { flex: 1, fontFamily: fonts.bodyBold, fontSize: 12, color: colors.ink },
  hostSig: { fontFamily: fonts.body, color: colors.inkSoft },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 12 },
  rowIcon: { width: 38, height: 38, borderRadius: 12, backgroundColor: colors.brandPale, alignItems: 'center', justifyContent: 'center' },
});
