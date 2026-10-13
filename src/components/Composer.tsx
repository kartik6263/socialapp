import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, TextInput, View } from 'react-native';
import { colors, fonts } from '@/theme';
import { Icon, T } from './ui';
import { tr, useLanguage } from '@/i18n';

const MAX = 2000;

export function Composer({ onSend, placeholder = tr('Write a message…'), note }: { onSend: (text: string) => void; placeholder?: string; note?: string }) {
  useLanguage();
  const [draft, setDraft] = useState('');
  const send = () => {
    const text = draft.trim();
    if (!text) return;
    onSend(text);
    setDraft('');
  };
  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={0}>
      <View style={styles.bar}>
        <TextInput
          value={draft}
          onChangeText={setDraft}
          placeholder={placeholder}
          placeholderTextColor="#8a9893"
          multiline
          maxLength={MAX}
          style={styles.input}
          accessibilityLabel={placeholder}
        />
        <Pressable onPress={send} disabled={!draft.trim()} accessibilityRole="button" accessibilityLabel={tr('Send')} style={[styles.send, !draft.trim() && { opacity: 0.4 }]}>
          <Icon name="arrow-right" size={18} color="#fff" />
        </Pressable>
      </View>
      {note ? <T variant="caption" style={{ textAlign: 'center', paddingBottom: 6, backgroundColor: colors.surface }}>{note}</T> : null}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  bar: { flexDirection: 'row', alignItems: 'flex-end', gap: 8, padding: 10, borderTopWidth: 1, borderTopColor: colors.line, backgroundColor: colors.surface },
  input: { flex: 1, maxHeight: 120, minHeight: 44, borderRadius: 22, backgroundColor: colors.paper, paddingHorizontal: 16, paddingTop: 12, paddingBottom: 12, fontFamily: fonts.body, fontSize: 14, color: colors.ink },
  send: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.brand, alignItems: 'center', justifyContent: 'center' },
});
