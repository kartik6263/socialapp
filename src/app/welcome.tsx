import { router } from 'expo-router';
import { useEffect, useRef } from 'react';
import { Animated, Easing, StyleSheet, Text, View } from 'react-native';
import { Glass } from '@/components/glass';
import { LanguagePicker } from '@/components/LanguagePicker';
import { Appear, useReducedMotion } from '@/components/motion';
import { Avatar, Banner, Button, Headline, Icon, Logo, Screen, T, type IconName } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { colors, fonts, glass } from '@/theme';
import { tr, useLanguage } from '@/i18n';

/** People drifting gently around a Plan: the whole idea of the app in one picture. Still when reduce-motion is on. */
function Orbit() {
  const still = useReducedMotion();
  const t = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (still) return;
    const loop = Animated.loop(Animated.timing(t, { toValue: 1, duration: 6000, easing: Easing.inOut(Easing.sin), useNativeDriver: true }));
    loop.start();
    return () => loop.stop();
  }, [still, t]);
  const bob = (phase: number, dist = 6) => ({
    transform: [{ translateY: t.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0, (phase % 2 ? 1 : -1) * dist, 0] }) }],
  });
  return (
    <View style={styles.art} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <View style={styles.ringOuter} />
      <View style={styles.ring} />
      <Animated.View style={[styles.orbit, { top: 0, left: '42%' }, bob(0)]}><Avatar name="Riya K" size={48} tone="mint" /></Animated.View>
      <Animated.View style={[styles.orbit, { bottom: 10, left: '16%' }, bob(1, 8)]}><Avatar name="Vikram S" size={48} tone="violet" /></Animated.View>
      <Animated.View style={[styles.orbit, { bottom: 36, right: '14%' }, bob(2, 5)]}><Avatar name="Nisha M" size={48} tone="coral" /></Animated.View>
      <Glass radius={24} style={styles.center}>
        <View style={styles.centerInner}><Icon name="calendar" size={28} color={colors.brandDark} /></View>
      </Glass>
      <View style={[styles.tag, { top: 46, left: 6 }]}><Text style={styles.tagText}>{tr('Sunrise trek')}</Text></View>
      <View style={[styles.tag, { top: 70, right: 4 }]}><Text style={styles.tagText}>{tr('Live music')}</Text></View>
    </View>
  );
}

function PromiseRow({ icon, text }: { icon: IconName; text: string }) {
  return (
    <View style={styles.promise}>
      <View style={styles.promiseIcon}><Icon name={icon} size={14} color={colors.brandDark} /></View>
      <T variant="small" style={{ flex: 1, color: colors.ink }}>{text}</T>
    </View>
  );
}

export default function Welcome() {
  useLanguage();
  const { sessionExpired } = useAuth();
  return (
    <Screen edges={['top', 'bottom']}>
      <View style={styles.header}>
        <Logo />
        <View style={styles.safety}>
          <Icon name="shield" size={12} color={colors.brandDark} />
          <Text style={styles.safetyText}>{tr('Safety by design')}</Text>
        </View>
      </View>
      <LanguagePicker />

      <Orbit />

      {sessionExpired ? (
        <View style={{ marginBottom: 16 }}>
          <Banner icon="clock" tone="warn" title={tr('Your session expired')} body={tr('Sign in again and we’ll take you back to your Plans.')} />
        </View>
      ) : null}

      <Appear delay={80}>
        <T variant="kicker">{tr('PEOPLE AROUND YOUR PLANS')}</T>
        <View style={{ marginTop: 10, marginBottom: 12 }}>
          <Headline text={tr('Tell us what\nyou’re ')} accent={tr('doing.')} />
        </View>
        <T variant="body" style={{ fontSize: 15, lineHeight: 22 }}>
          {tr('We’ll help you discover people doing the same thing—not keep you scrolling endlessly.')}
        </T>
      </Appear>

      <Appear delay={160}>
        <Glass style={styles.promises}>
          <PromiseRow icon="calendar" text={tr('Real Plans, not an endless feed')} />
          <PromiseRow icon="map-pin" text={tr('Approximate areas only — never your address')} />
          <PromiseRow icon="lock" text={tr('Your phone and email stay private')} />
        </Glass>
      </Appear>

      <Appear delay={240} style={{ gap: 10, marginTop: 20 }}>
        <Button label={tr('Get started')} iconRight="arrow-right" onPress={() => router.push({ pathname: '/sign-in', params: { mode: 'signup' } })} />
        <Button label={tr('Sign in')} kind="secondary" onPress={() => router.push({ pathname: '/sign-in', params: { mode: 'login' } })} />
      </Appear>
      <View style={styles.foot}>
        <T variant="caption">{tr('Free to use · 18+ only')}</T>
        <Button label={tr('Legal & privacy')} kind="text" compact onPress={() => router.push('/legal')} />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 14 },
  safety: { flexDirection: 'row', alignItems: 'center', gap: 5, backgroundColor: glass.fillStrong, borderWidth: 1, borderColor: glass.border, paddingHorizontal: 10, paddingVertical: 6, borderRadius: 999 },
  safetyText: { fontFamily: fonts.bodyBold, fontSize: 11, color: colors.brandDark },
  art: { height: 236, marginVertical: 16, justifyContent: 'center', alignItems: 'center' },
  ringOuter: { position: 'absolute', width: 236, height: 236, borderRadius: 118, borderWidth: 1, borderColor: 'rgba(18,107,85,0.10)' },
  ring: { position: 'absolute', width: 190, height: 190, borderRadius: 95, borderWidth: 1, borderStyle: 'dashed', borderColor: 'rgba(18,107,85,0.35)' },
  orbit: { position: 'absolute', borderWidth: 3, borderColor: 'rgba(255,255,255,0.95)', borderRadius: 30 },
  center: { width: 72, height: 72, transform: [{ rotate: '-7deg' }] },
  centerInner: { flex: 1, margin: 6, borderRadius: 18, backgroundColor: colors.lime, alignItems: 'center', justifyContent: 'center' },
  tag: { position: 'absolute', backgroundColor: glass.fillStrong, borderWidth: 1, borderColor: glass.border, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 5 },
  tagText: { fontFamily: fonts.bodyBold, fontSize: 11, color: colors.ink },
  promises: { padding: 14, gap: 10, marginTop: 18 },
  promise: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  promiseIcon: { width: 26, height: 26, borderRadius: 9, backgroundColor: colors.brandPale, alignItems: 'center', justifyContent: 'center' },
  foot: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: 10 },
});
