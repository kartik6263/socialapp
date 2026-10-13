import { LinearGradient } from 'expo-linear-gradient';
import { router, Tabs } from 'expo-router';
import { useEffect, useRef, type ComponentProps } from 'react';
import { Animated, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Glass } from '@/components/glass';
import { useFocusRing, usePressScale, useReducedMotion } from '@/components/motion';
import { Icon, type IconName } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { aurora, brandGradient, colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

type BottomTabBarProps = Parameters<NonNullable<ComponentProps<typeof Tabs>['tabBar']>>[0];

const ITEMS: Record<string, { label: string; icon: IconName }> = {
  index: { label: 'Discover', icon: 'home' },
  plans: { label: 'My plans', icon: 'calendar' },
  chats: { label: 'Chats', icon: 'message-circle' },
  me: { label: 'Profile', icon: 'user' },
};

function TabItem({ label, icon, focused, badge, onPress }: { label: string; icon: IconName; focused: boolean; badge: string | null; onPress: () => void }) {
  const still = useReducedMotion();
  const on = useRef(new Animated.Value(focused ? 1 : 0)).current;
  const focus = useFocusRing();
  useEffect(() => {
    if (still) on.setValue(focused ? 1 : 0);
    else Animated.spring(on, { toValue: focused ? 1 : 0, useNativeDriver: true, speed: 18, bounciness: 8 }).start();
  }, [focused, still, on]);
  return (
    <Pressable
      accessibilityRole="tab"
      accessibilityState={{ selected: focused }}
      accessibilityLabel={badge ? tr('{label}, {badge} unread conversations', { label, badge }) : label}
      onPress={onPress}
      {...focus.handlers}
      style={[styles.item, focus.ring && { borderRadius: 16, ...focus.ring }]}
    >
      <View style={styles.iconWrap}>
        {/* The active tab gets a soft pill of light behind its icon. */}
        <Animated.View style={[styles.pill, { opacity: on, transform: [{ scale: on.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1] }) }] }]} />
        <Icon name={icon} size={20} color={focused ? colors.brandDark : colors.inkSoft} />
        {badge ? <View style={styles.badge}><Text style={styles.badgeText}>{badge}</Text></View> : null}
      </View>
      <Text style={[styles.label, focused && { color: colors.brandDark }]} numberOfLines={1}>{label}</Text>
    </Pressable>
  );
}

function TabBar({ state, navigation }: BottomTabBarProps) {
  useLanguage();
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const unreadChats = user?.unreadConversations ?? 0;
  const create = usePressScale(0.92);
  const createFocus = useFocusRing();

  const tab = (routeName: string) => {
    const index = state.routes.findIndex((r: { name: string }) => r.name === routeName);
    const item = ITEMS[routeName];
    const badge = routeName === 'chats' && unreadChats > 0 ? (unreadChats > 9 ? '9+' : String(unreadChats)) : null;
    return <TabItem key={routeName} label={tr(item.label)} icon={item.icon} focused={state.index === index} badge={badge} onPress={() => navigation.navigate(routeName)} />;
  };

  return (
    <View style={[styles.wrap, { paddingBottom: Math.max(insets.bottom, 10) }]}>
      <Glass blur radius={28} style={styles.bar}>
        <View style={styles.row} accessibilityRole="tablist">
          {tab('index')}
          {tab('plans')}
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={tr('Create a Plan')}
            onPress={() => router.push('/plan/new')}
            onPressIn={create.onPressIn}
            onPressOut={create.onPressOut}
            {...createFocus.handlers}
            style={styles.item}
          >
            <Animated.View style={[styles.create, createFocus.ring, { transform: [{ rotate: '-4deg' }, ...create.style.transform] }]}>
              <LinearGradient colors={brandGradient} style={[StyleSheet.absoluteFill, { borderRadius: 18 }]} />
              <Icon name="plus" size={22} color="#fff" />
            </Animated.View>
          </Pressable>
          {tab('chats')}
          {tab('me')}
        </View>
      </Glass>
    </View>
  );
}

export default function TabsLayout() {
  return (
    <Tabs screenOptions={{ headerShown: false }} tabBar={(p) => <TabBar {...p} />}>
      <Tabs.Screen name="index" />
      <Tabs.Screen name="plans" />
      <Tabs.Screen name="chats" />
      <Tabs.Screen name="me" />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  // Matches the bottom of the screen backdrop so the floating bar doesn't sit on a visible strip.
  wrap: { backgroundColor: aurora.base[2], paddingHorizontal: 12, paddingTop: 6 },
  bar: { paddingVertical: 6 },
  row: { flexDirection: 'row', alignItems: 'center' },
  item: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 2, minHeight: 52 },
  iconWrap: { width: 52, height: 30, alignItems: 'center', justifyContent: 'center' },
  pill: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, borderRadius: 15, backgroundColor: colors.brandPale },
  label: { fontFamily: fonts.bodyBold, fontSize: 10, color: colors.inkSoft },
  create: {
    width: 50, height: 50, borderRadius: 18, alignItems: 'center', justifyContent: 'center',
    shadowColor: '#0c4f40', shadowOpacity: 0.35, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 5,
  },
  badge: { position: 'absolute', right: 6, top: -4, minWidth: 17, height: 17, borderRadius: 9, paddingHorizontal: 4, backgroundColor: colors.badge, borderWidth: 2, borderColor: '#fff', alignItems: 'center', justifyContent: 'center' },
  badgeText: { color: '#fff', fontSize: 9, fontFamily: fonts.bodyBold },
});
