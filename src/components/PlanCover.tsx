import Feather from '@expo/vector-icons/Feather';
import { LinearGradient } from 'expo-linear-gradient';
import { Image, StyleSheet, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import type { PlanSummary } from '@/api/types';
import { categoryLabel } from '@/lib/categories';
import { tr } from '@/i18n';
import type { IconName } from './ui';

/**
 * Cover art drawn by the app: a gradient and an icon per category. Nothing is licensed from a third party,
 * so there is no image rights question. A host’s own uploaded cover (coverImageUrl) is shown instead when set.
 */
const ART: Record<string, { colors: [string, string]; icon: IconName }> = {
  travel: { colors: ['#1f8a8a', '#0d4d5c'], icon: 'map' },
  trek: { colors: ['#3d8a4f', '#1b4d33'], icon: 'triangle' },
  photography: { colors: ['#6b5bc9', '#33296e'], icon: 'camera' },
  concert: { colors: ['#b8487a', '#5c1f45'], icon: 'music' },
  event: { colors: ['#c06a2b', '#6b3312'], icon: 'star' },
  sports: { colors: ['#2f7fc1', '#163f6b'], icon: 'activity' },
  gaming: { colors: ['#7046b8', '#2e1d5e'], icon: 'monitor' },
  college: { colors: ['#3c6fb0', '#1c355e'], icon: 'book-open' },
  hackathon: { colors: ['#2b7a6b', '#123d38'], icon: 'code' },
  networking: { colors: ['#4a6a8c', '#22344a'], icon: 'users' },
  food: { colors: ['#c4572d', '#6e2814'], icon: 'coffee' },
  movie: { colors: ['#8a3f5c', '#3e1a2b'], icon: 'film' },
};
const FALLBACK = { colors: ['#178066', '#0c4f40'] as [string, string], icon: 'calendar' as IconName };

export function PlanCover({ plan, iconSize = 64 }: { plan: Pick<PlanSummary, 'category' | 'coverImageUrl'>; iconSize?: number }) {
  if (plan.coverImageUrl) {
    return (
      <Image
        source={{ uri: plan.coverImageUrl }}
        style={StyleSheet.absoluteFill}
        resizeMode="cover"
        accessible
        accessibilityLabel={tr('Cover photo for this {category} Plan', { category: categoryLabel(plan.category) })}
      />
    );
  }
  const art = ART[plan.category.toLowerCase()] ?? FALLBACK;
  return (
    // Decorative: the category is also written on the card, so screen readers skip the art.
    <View style={StyleSheet.absoluteFill} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <LinearGradient colors={art.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={StyleSheet.absoluteFill} />
      <Svg style={StyleSheet.absoluteFill} width="100%" height="100%">
        <Circle cx="88%" cy="18%" r="70" fill="rgba(255,255,255,0.09)" />
        <Circle cx="10%" cy="110%" r="90" fill="rgba(255,255,255,0.07)" />
        <Circle cx="70%" cy="95%" r="34" fill="rgba(223,240,96,0.22)" />
      </Svg>
      <View style={styles.icon}>
        <Feather name={art.icon} size={iconSize} color="rgba(255,255,255,0.28)" />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  icon: { position: 'absolute', right: 18, bottom: 12, transform: [{ rotate: '-8deg' }] },
});
