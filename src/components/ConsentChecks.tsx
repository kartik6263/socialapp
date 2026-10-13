import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, fonts, glass } from '@/theme';
import { useFocusRing } from './motion';
import { Icon } from './ui';
import { tr, useLanguage } from '@/i18n';

export interface ConsentState { terms: boolean; adult: boolean }

/**
 * The two agreements needed to create an account, as separate unticked boxes (no bundling, no pre-ticking).
 * Policy names are links that open the full text first.
 */
export function ConsentChecks({ value, onChange, error }: { value: ConsentState; onChange: (v: ConsentState) => void; error?: boolean }) {
  useLanguage();
  const open = (slug: string) => router.push({ pathname: '/legal/[slug]', params: { slug } });
  return (
    <View style={{ gap: 10, marginBottom: 18 }}>
      <Check
        checked={value.terms}
        onToggle={() => onChange({ ...value, terms: !value.terms })}
        error={error && !value.terms}
        a11y={tr('I agree to the Terms of service and the Privacy policy')}
      >
        {tr('I agree to the ')}
        <Text style={styles.link} accessibilityRole="link" onPress={() => open('terms')}>{tr('Terms of service')}</Text>
        {tr(' and the ')}
        <Text style={styles.link} accessibilityRole="link" onPress={() => open('privacy')}>{tr('Privacy policy')}</Text>
        {tr('.')}
      </Check>
      {/* The links inside the checkbox can't be reached separately by screen readers; these can. */}
      <View style={styles.reads}>
        <Text style={styles.readLink} accessibilityRole="link" onPress={() => open('terms')}>{tr('Read the Terms')}</Text>
        <Text style={styles.dot} importantForAccessibility="no">·</Text>
        <Text style={styles.readLink} accessibilityRole="link" onPress={() => open('privacy')}>{tr('Read the Privacy policy')}</Text>
      </View>
      <Check
        checked={value.adult}
        onToggle={() => onChange({ ...value, adult: !value.adult })}
        error={error && !value.adult}
        a11y={tr('I confirm I am 18 or older')}
      >
        {tr('I confirm I’m 18 or older. Plans is for adults only.')}
      </Check>
      {error && !(value.terms && value.adult) ? (
        <Text style={styles.error} accessibilityRole="alert" accessibilityLiveRegion="polite">{tr('Tick both boxes to create an account.')}</Text>
      ) : null}
    </View>
  );
}

function Check({ checked, onToggle, error, a11y, children }: { checked: boolean; onToggle: () => void; error?: boolean; a11y: string; children: React.ReactNode }) {
  const focus = useFocusRing();
  return (
    <Pressable onPress={onToggle} {...focus.handlers} accessibilityRole="checkbox" accessibilityState={{ checked }} accessibilityLabel={a11y}
      style={[styles.row, focus.ring && { ...focus.ring, borderRadius: 12 }]} hitSlop={4}>
      <View style={[styles.box, checked && styles.boxOn, error && { borderColor: colors.dangerText }]}>
        {checked ? <Icon name="check" size={14} color="#fff" /> : null}
      </View>
      <Text style={styles.text}>{children}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 12, alignItems: 'flex-start', padding: 12, borderRadius: 16, backgroundColor: glass.fill, borderWidth: 1, borderColor: glass.border, minHeight: 48 },
  box: { width: 22, height: 22, borderRadius: 7, borderWidth: 2, borderColor: colors.inputBorder, alignItems: 'center', justifyContent: 'center', marginTop: 1, backgroundColor: '#fff' },
  boxOn: { backgroundColor: colors.brand, borderColor: colors.brand },
  text: { flex: 1, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, color: colors.inkSoft },
  reads: { flexDirection: 'row', gap: 8, paddingHorizontal: 4, marginTop: -2 },
  readLink: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.brand, paddingVertical: 6 },
  dot: { color: colors.inkSoft, paddingVertical: 6 },
  error: { fontFamily: fonts.bodySemi, fontSize: 12, color: colors.dangerText },
  link: { fontFamily: fonts.bodyBold, color: colors.brand, textDecorationLine: 'underline' },
});
