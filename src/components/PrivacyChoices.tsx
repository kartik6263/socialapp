import { useEffect, useRef, useState } from 'react';
import { Animated, Modal, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ApiError, contentApi, privacyApi, setAnalyticsAllowed, type ContentPage } from '@/api';
import { Markdown } from './Markdown';
import { colors, fonts, glass, motion } from '@/theme';
import { useReducedMotion } from './motion';
import { Button, Group, IconTile, T, ToggleRow } from './ui';
import { tr, useLanguage } from '@/i18n';

/**
 * The app's consent prompt (it has no cookies; this covers the optional data uses instead). Shown once, after sign-in,
 * until the person answers. Rules it follows on purpose:
 * - optional uses start OFF; "Reject all" and "Accept all" look identical, so neither is nudged;
 * - essential uses are explained but not toggleable;
 * - the choice can be changed any time in Settings → Your data.
 */
export function PrivacyChoices() {
  useLanguage();
  const insets = useSafeAreaInsets();
  const still = useReducedMotion();
  const [open, setOpen] = useState(false);
  const [custom, setCustom] = useState(false);
  const [analytics, setAnalytics] = useState(false);
  const [offers, setOffers] = useState(false);
  const [emails, setEmails] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const rise = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    privacyApi.consents().then((c) => {
      setAnalyticsAllowed(c.analytics);
      if (!c.decided) setOpen(true);
    }).catch(() => undefined); // offline: ask next launch; nothing optional runs meanwhile
  }, []);

  useEffect(() => {
    if (!open) return;
    if (still) rise.setValue(1);
    else Animated.timing(rise, { toValue: 1, duration: motion.slow, useNativeDriver: true }).start();
  }, [open, still, rise]);

  const save = async (which: string, choice: { analytics: boolean; offers: boolean; marketingEmails: boolean }) => {
    setBusy(which);
    setError(null);
    try {
      const saved = await privacyApi.saveConsents({ ...choice, source: 'PROMPT' });
      setAnalyticsAllowed(saved.analytics);
      setOpen(false);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      setBusy(null);
    }
  };

  // Policies open inside the prompt (a separate screen would sit underneath it).
  const [reading, setReading] = useState<ContentPage | 'loading' | 'error' | null>(null);
  const policy = (slug: string) => {
    setReading('loading');
    contentApi.page(slug).then(setReading).catch(() => setReading('error'));
  };

  return (
    <Modal visible={open} transparent animationType="fade" statusBarTranslucent onRequestClose={() => undefined}>
      <View style={styles.scrim}>
        <Animated.View
          accessibilityViewIsModal
          style={[styles.sheet, { paddingBottom: insets.bottom + 18, opacity: rise, transform: [{ translateY: rise.interpolate({ inputRange: [0, 1], outputRange: [40, 0] }) }] }]}
        >
          {reading ? (
            <View style={{ maxHeight: 520 }}>
              <Button label={tr('Back to choices')} kind="text" icon="chevron-left" onPress={() => setReading(null)} style={{ alignSelf: 'flex-start' }} />
              {reading === 'loading' ? <T variant="small">{tr('Loading…')}</T>
                : reading === 'error' ? <T variant="small">{tr('Couldn’t load this page. You can read it later in Settings → Legal & privacy.')}</T>
                : <ScrollView style={{ marginTop: 6 }}><Markdown text={reading.body} /></ScrollView>}
            </View>
          ) : (
          <>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <IconTile name="sliders" tone="ok" size={44} />
            <T variant="heading" accessibilityRole="header" style={{ flex: 1, fontSize: 19 }}>{tr('Your privacy choices')}</T>
          </View>
          <T variant="body" style={{ marginTop: 10 }}>
            {tr('Plans works fully without these. They’re off unless you turn them on, and you can change them any time in Settings → Your data.')}
          </T>

          {custom ? (
            <Group style={{ marginTop: 14 }}>
              <ToggleRow first label={tr('Product analytics')} sub={tr('Counts of actions like “Plan joined”. No messages, no location, no ads.')} value={analytics} onChange={setAnalytics} />
              <ToggleRow label={tr('Offers & promotions')} sub={tr('Occasional notifications about event deals.')} value={offers} onChange={setOffers} />
              <ToggleRow label={tr('Update emails')} sub={tr('News by email, with an unsubscribe link in every one.')} value={emails} onChange={setEmails} />
            </Group>
          ) : (
            <View style={styles.list}>
              <Line on={false} text={tr('Product analytics — off until you choose')} />
              <Line on={false} text={tr('Offers & promotions — off until you choose')} />
              <Line on text={tr('Essential: sign-in, your profile, Plans, chat and safety — always on')} />
            </View>
          )}

          <Text style={styles.links}>
            <Text style={styles.link} accessibilityRole="link" onPress={() => policy('privacy')}>{tr('Privacy policy')}</Text>
            {'   ·   '}
            <Text style={styles.link} accessibilityRole="link" onPress={() => policy('cookie-policy')}>{tr('Cookie & storage policy')}</Text>
          </Text>

          {error ? <T variant="small" style={{ color: colors.dangerText, marginTop: 8 }} accessibilityRole="alert">{error}</T> : null}

          {custom ? (
            <Button label={tr('Save my choices')} loading={busy === 'custom'} disabled={!!busy} style={{ marginTop: 14 }}
              onPress={() => save('custom', { analytics, offers, marketingEmails: emails })} />
          ) : (
            <>
              {/* Same style, same size, side by side: no nudging towards "accept". */}
              <View style={{ flexDirection: 'row', gap: 10, marginTop: 14 }}>
                <Button label={tr('Reject all')} kind="secondary" loading={busy === 'reject'} disabled={!!busy} style={{ flex: 1 }}
                  onPress={() => save('reject', { analytics: false, offers: false, marketingEmails: false })} />
                <Button label={tr('Accept all')} kind="secondary" loading={busy === 'accept'} disabled={!!busy} style={{ flex: 1 }}
                  onPress={() => save('accept', { analytics: true, offers: true, marketingEmails: true })} />
              </View>
              <Button label={tr('Choose for myself')} kind="text" disabled={!!busy} onPress={() => setCustom(true)} style={{ marginTop: 4 }} />
            </>
          )}
          </>
          )}
        </Animated.View>
      </View>
    </Modal>
  );
}

function Line({ on, text }: { on: boolean; text: string }) {
  return (
    <View style={{ flexDirection: 'row', gap: 8, alignItems: 'flex-start' }}>
      <Text style={[styles.mark, { color: on ? colors.brand : colors.inkSoft }]} importantForAccessibility="no">{on ? '●' : '○'}</Text>
      <T variant="small" style={{ flex: 1, fontSize: 13 }}>{text}</T>
    </View>
  );
}

const styles = StyleSheet.create({
  scrim: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(15,25,23,0.4)' },
  sheet: { backgroundColor: 'rgba(247,250,247,0.98)', borderTopLeftRadius: 30, borderTopRightRadius: 30, padding: 20, borderWidth: 1, borderColor: glass.border },
  list: { gap: 8, marginTop: 14 },
  mark: { fontSize: 12, lineHeight: 19 },
  links: { marginTop: 14, fontFamily: fonts.body, fontSize: 12, color: colors.inkSoft },
  link: { fontFamily: fonts.bodyBold, color: colors.brand, textDecorationLine: 'underline' },
});
