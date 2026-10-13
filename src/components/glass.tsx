import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { memo, type ReactNode } from 'react';
import { Platform, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import Svg, { Defs, RadialGradient, Rect, Stop } from 'react-native-svg';
import { aurora, glass } from '@/theme';

/**
 * The light behind every screen. Three soft radial glows on a pale base — static, so it costs nothing per frame.
 * Purely decorative: hidden from screen readers.
 */
export const Backdrop = memo(function Backdrop() {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none" accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <LinearGradient colors={aurora.base} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={StyleSheet.absoluteFill} />
      <Svg style={StyleSheet.absoluteFill} width="100%" height="100%">
        <Defs>
          <Glow id="mint" color={aurora.mint} />
          <Glow id="lime" color={aurora.lime} />
          <Glow id="violet" color={aurora.violet} />
        </Defs>
        <Rect x="-35%" y="-20%" width="110%" height="60%" fill="url(#mint)" />
        <Rect x="45%" y="-10%" width="80%" height="40%" fill="url(#lime)" />
        <Rect x="10%" y="55%" width="110%" height="60%" fill="url(#violet)" />
      </Svg>
    </View>
  );
});

function Glow({ id, color }: { id: string; color: string }) {
  return (
    <RadialGradient id={id} cx="50%" cy="50%" r="50%">
      <Stop offset="0" stopColor={color} stopOpacity={1} />
      <Stop offset="1" stopColor={color} stopOpacity={0} />
    </RadialGradient>
  );
}

/**
 * A frosted surface. Real blur only where it earns its cost (floating bars, sheets — pass `blur`), and only on iOS:
 * Expo Go’s Android blur needs a wrapper around every screen and is slow on older phones, so Android gets a
 * slightly more opaque fill that reads the same.
 */
export function Glass({ children, style, blur, strong, radius = 20 }: {
  children?: ReactNode; style?: StyleProp<ViewStyle>; blur?: boolean; strong?: boolean; radius?: number;
}) {
  const realBlur = blur && Platform.OS === 'ios';
  return (
    <View style={[styles.glass, { borderRadius: radius, backgroundColor: realBlur ? 'rgba(255,255,255,0.45)' : strong ? glass.fillStrong : glass.fill }, style]}>
      {/* Clipped layer for blur + top highlight, so the outer view can keep its shadow (iOS drops shadows on clipped views). */}
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { borderRadius: radius, overflow: 'hidden' }]}>
        {realBlur ? <BlurView intensity={40} tint="light" style={StyleSheet.absoluteFill} /> : null}
        <View style={styles.highlight} />
      </View>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  glass: { borderWidth: 1, borderColor: glass.border, ...glass.shadow },
  highlight: { position: 'absolute', top: 0, left: 0, right: 0, height: 1, backgroundColor: glass.highlight },
});
