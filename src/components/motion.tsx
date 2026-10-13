import { useEffect, useRef, useState, type ReactNode } from 'react';
import { AccessibilityInfo, Animated, Easing, type StyleProp, type ViewStyle } from 'react-native';
import { motion } from '@/theme';

/**
 * Motion is used for three jobs only: confirming a touch (press), orienting on arrival (appear), and showing a
 * state change (switches, tabs, sheets). Everything turns off when the person has "Reduce motion" on.
 */
let reduced = false;
const listeners = new Set<(v: boolean) => void>();
void AccessibilityInfo.isReduceMotionEnabled().then((v) => {
  reduced = v;
  listeners.forEach((l) => l(v));
});
AccessibilityInfo.addEventListener('reduceMotionChanged', (v) => {
  reduced = v;
  listeners.forEach((l) => l(v));
});

export function useReducedMotion() {
  const [v, setV] = useState(reduced);
  useEffect(() => {
    listeners.add(setV);
    return () => {
      listeners.delete(setV);
    };
  }, []);
  return v;
}

/** Fades content in and lifts it 10px — once, on mount. `delay` staggers siblings. */
export function Appear({ children, delay = 0, style }: { children: ReactNode; delay?: number; style?: StyleProp<ViewStyle> }) {
  const still = useReducedMotion();
  const t = useRef(new Animated.Value(still ? 1 : 0)).current;
  useEffect(() => {
    if (still) {
      t.setValue(1);
      return;
    }
    Animated.timing(t, { toValue: 1, duration: motion.slow, delay, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }, [still, delay, t]);
  return (
    <Animated.View style={[style, { opacity: t, transform: [{ translateY: t.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }] }]}>
      {children}
    </Animated.View>
  );
}

/** A spring that dips to `to` while pressed. Returns handlers for a Pressable and the animated style. */
export function usePressScale(to = 0.97) {
  const still = useReducedMotion();
  const s = useRef(new Animated.Value(1)).current;
  const go = (v: number) => {
    if (still) return;
    Animated.spring(s, { toValue: v, useNativeDriver: true, speed: 40, bounciness: v === 1 ? 6 : 0 }).start();
  };
  return {
    onPressIn: () => go(to),
    onPressOut: () => go(1),
    style: { transform: [{ scale: s }] },
  };
}

/**
 * Visible focus for keyboard and switch-access users (Tab / arrow keys on a hardware keyboard).
 * Spread `handlers` on the Pressable and add `ring` to its style.
 */
export function useFocusRing() {
  const [focused, setFocused] = useState(false);
  return {
    focused,
    handlers: { onFocus: () => setFocused(true), onBlur: () => setFocused(false) },
    ring: focused ? FOCUS_RING : null,
  };
}

export const FOCUS_RING: ViewStyle = { borderWidth: 2, borderColor: '#0b5cad' };
