import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { SharedPlanRef } from '@/api/types';
import { colors, fonts } from '@/theme';
import { Icon, IconTile, type IconName } from './ui';

/** "YOU’RE BOTH JOINING · Weekend Photography Walk" card, used on requests, profiles and chats. */
export function SharedPlanCard({ plan, onPress, icon = 'calendar' }: { plan: SharedPlanRef; onPress: () => void; icon?: IconName }) {
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={`${plan.label}: ${plan.title}, ${plan.when}`} style={({ pressed }) => [styles.card, pressed && { opacity: 0.92 }]}>
      <IconTile name={icon} />
      <View style={{ flex: 1 }}>
        <Text style={styles.kicker}>{plan.label}</Text>
        <Text style={styles.title}>{plan.title}</Text>
        <Text style={styles.sub}>{plan.when}</Text>
      </View>
      <Icon name="arrow-right" size={16} color={colors.brand} />
    </Pressable>
  );
}

export function ContextRow({ icon, label, value }: { icon: IconName; label: string; value: string }) {
  return (
    <View style={styles.ctx}>
      <IconTile name={icon} tone="lime" size={34} />
      <View style={{ flex: 1 }}>
        <Text style={styles.kicker}>{label}</Text>
        <Text style={styles.title}>{value}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, padding: 13 },
  ctx: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8 },
  kicker: { fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 1.1, color: colors.inkSoft },
  title: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink, marginTop: 1 },
  sub: { fontFamily: fonts.body, fontSize: 12, color: colors.inkSoft, marginTop: 1 },
});
