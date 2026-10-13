import { useState, type ReactNode } from 'react';
import { KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ApiError } from '@/api';
import { colors, fonts, glass } from '@/theme';
import type { PillTone } from '@/theme';
import { Button, Icon, IconTile, T, type IconName } from './ui';
import { tr, useLanguage } from '@/i18n';

export function Sheet({ visible, onClose, children, label }: { visible: boolean; onClose: () => void; children: ReactNode; label?: string }) {
  useLanguage();
  const insets = useSafeAreaInsets();
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose} statusBarTranslucent>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
        <Pressable style={styles.backdrop} onPress={onClose} accessibilityLabel={tr('Close')} />
        <View style={[styles.sheet, { paddingBottom: insets.bottom + 16 }]} accessibilityViewIsModal accessibilityLabel={label}>
          <View style={styles.handle} />
          <ScrollView keyboardShouldPersistTaps="handled" bounces={false}>{children}</ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

export interface SheetAction {
  label: string;
  icon: IconName;
  sub?: string;
  danger?: boolean;
  onPress: () => void;
}

/** "⋯" menus: Report / Block / Mute etc. Closes before running the action. */
export function ActionSheet({ visible, onClose, title, sub, quote, actions }: {
  visible: boolean; onClose: () => void; title: string; sub?: string | null; quote?: string | null; actions: SheetAction[];
}) {
  useLanguage();
  return (
    <Sheet visible={visible} onClose={onClose} label={title}>
      <T variant="heading">{title}</T>
      {sub ? (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 4 }}>
          <Icon name="link" size={12} color={colors.inkSoft} />
          <T variant="small">{sub}</T>
        </View>
      ) : null}
      {quote ? <Text style={styles.quote}>“{quote}”</Text> : null}
      <View style={styles.actions}>
        {actions.map((a, i) => (
          <Pressable
            key={a.label}
            accessibilityRole="button"
            onPress={() => {
              onClose();
              setTimeout(a.onPress, 250);
            }}
            style={({ pressed }) => [styles.action, i > 0 && { borderTopWidth: 1, borderTopColor: colors.divider }, pressed && { backgroundColor: colors.paper }]}
          >
            <Icon name={a.icon} size={19} color={a.danger ? colors.danger : colors.ink} />
            <View style={{ flex: 1 }}>
              <Text style={[styles.actionLabel, a.danger && { color: colors.danger }]}>{a.label}</Text>
              {a.sub ? <T variant="small">{a.sub}</T> : null}
            </View>
          </Pressable>
        ))}
      </View>
      <Button label={tr('Cancel')} kind="secondary" onPress={onClose} style={{ marginTop: 12 }} />
    </Sheet>
  );
}

/** Centered confirmation dialog (block, unblock, sign out, deactivate…). */
export function ConfirmDialog({
  visible, onClose, title, body, okLabel, cancelLabel = tr('Cancel'), onConfirm, icon = 'alert-circle', tone = 'ok', okKind = 'primary',
}: {
  visible: boolean; onClose: () => void; title: string; body: string; okLabel: string; cancelLabel?: string;
  onConfirm: () => Promise<void> | void; icon?: IconName; tone?: PillTone; okKind?: 'primary' | 'dangerSolid' | 'ink';
}) {
  useLanguage();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const confirm = async () => {
    setBusy(true);
    setError('');
    try {
      await onConfirm();
      onClose();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Something went wrong. Try again.'));
    } finally {
      setBusy(false);
    }
  };
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose} statusBarTranslucent>
      <View style={styles.center}>
        <View style={styles.dialog} accessibilityRole="alert" accessibilityViewIsModal>
          <IconTile name={icon} tone={tone} size={46} />
          <T variant="heading" style={{ marginTop: 12, fontSize: 19 }}>{title}</T>
          <T variant="body" style={{ marginTop: 6 }}>{body}</T>
          {error ? <T variant="small" style={{ color: colors.danger, marginTop: 10 }} accessibilityRole="alert">{error}</T> : null}
          <View style={{ flexDirection: 'row', gap: 8, marginTop: 18 }}>
            <Button label={cancelLabel} kind="secondary" onPress={onClose} style={{ flex: 1 }} />
            <Button label={okLabel} kind={okKind} loading={busy} onPress={confirm} style={{ flex: 1 }} />
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(15,25,23,0.4)' },
  // Sheets and dialogs float over a dimmed screen, so they stay nearly opaque to keep text contrast.
  sheet: { backgroundColor: 'rgba(247,250,247,0.97)', borderTopLeftRadius: 30, borderTopRightRadius: 30, borderWidth: 1, borderColor: glass.border, paddingHorizontal: 18, paddingTop: 10, maxHeight: '88%' },
  handle: { alignSelf: 'center', width: 40, height: 4, borderRadius: 2, backgroundColor: 'rgba(24,35,33,0.18)', marginBottom: 14 },
  quote: { fontFamily: fonts.body, fontStyle: 'italic', fontSize: 13, color: colors.inkSoft, backgroundColor: colors.surface, padding: 10, borderRadius: 12, marginTop: 10 },
  actions: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, marginTop: 14, overflow: 'hidden' },
  action: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 14 },
  actionLabel: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  center: { flex: 1, backgroundColor: 'rgba(15,25,23,0.45)', alignItems: 'center', justifyContent: 'center', padding: 24 },
  dialog: { width: '100%', maxWidth: 380, backgroundColor: 'rgba(255,255,255,0.97)', borderRadius: 26, padding: 20, borderWidth: 1, borderColor: glass.border, ...glass.shadow },
});
