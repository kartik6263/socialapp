import DateTimePicker, { DateTimePickerAndroid, type DateTimePickerEvent } from '@react-native-community/datetimepicker';
import { useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { planDate } from '@/lib/format';
import { colors, fonts } from '@/theme';
import { Sheet } from './Sheet';
import { Button, Icon } from './ui';
import { tr, useLanguage } from '@/i18n';

/** Date + time picker: native dialogs on Android, a bottom sheet with the inline picker on iOS. */
export function DateField({ label, value, onChange, optional, error, minimumDate }: {
  label: string; value: Date | null; onChange: (d: Date | null) => void; optional?: boolean; error?: string | null; minimumDate?: Date;
}) {
  useLanguage();
  const [iosOpen, setIosOpen] = useState(false);
  const [draft, setDraft] = useState<Date>(value ?? defaultDate());

  const open = () => {
    const base = value ?? defaultDate();
    if (Platform.OS === 'android') {
      DateTimePickerAndroid.open({
        value: base,
        mode: 'date',
        minimumDate,
        onChange: (e: DateTimePickerEvent, date?: Date) => {
          if (e.type !== 'set' || !date) return;
          DateTimePickerAndroid.open({
            value: date,
            mode: 'time',
            onChange: (e2: DateTimePickerEvent, time?: Date) => {
              if (e2.type !== 'set' || !time) return;
              const d = new Date(date);
              d.setHours(time.getHours(), time.getMinutes(), 0, 0);
              onChange(d);
            },
          });
        },
      });
    } else {
      setDraft(base);
      setIosOpen(true);
    }
  };

  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={styles.label}>
        {label}
        {optional ? <Text style={{ fontFamily: fonts.body, color: colors.inkSoft }}> {tr('(optional)')}</Text> : null}
      </Text>
      <Pressable onPress={open} style={[styles.input, error ? { borderColor: colors.danger } : null]} accessibilityRole="button" accessibilityLabel={`${label}: ${value ? planDate(value.toISOString()) : tr('not set')}`}>
        <Icon name="calendar" size={16} color={colors.inkSoft} />
        <Text style={[styles.value, !value && { color: '#8a9893' }]}>{value ? planDate(value.toISOString()) : tr('Choose date and time')}</Text>
        {value && optional ? (
          <Pressable onPress={() => onChange(null)} hitSlop={10} accessibilityLabel={tr('Clear {label}', { label })}>
            <Icon name="x" size={16} color={colors.inkSoft} />
          </Pressable>
        ) : null}
      </Pressable>
      {error ? <Text style={styles.error}>{error}</Text> : null}
      {Platform.OS === 'ios' ? (
        <Sheet visible={iosOpen} onClose={() => setIosOpen(false)} label={label}>
          <DateTimePicker value={draft} mode="datetime" display="inline" minimumDate={minimumDate} onChange={(_, d) => d && setDraft(d)} accentColor={colors.brand} />
          <Button label={tr('Done')} onPress={() => { onChange(draft); setIosOpen(false); }} style={{ marginTop: 8 }} />
        </Sheet>
      ) : null}
    </View>
  );
}

function defaultDate() {
  const d = new Date(Date.now() + 86400000);
  d.setHours(18, 0, 0, 0);
  return d;
}

const styles = StyleSheet.create({
  label: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.ink, marginBottom: 6 },
  input: { flexDirection: 'row', alignItems: 'center', gap: 8, minHeight: 50, borderWidth: 1, borderColor: colors.line, borderRadius: 14, backgroundColor: colors.surface, paddingHorizontal: 14 },
  value: { flex: 1, fontFamily: fonts.body, fontSize: 15, color: colors.ink },
  error: { fontFamily: fonts.bodySemi, fontSize: 12, color: colors.danger, marginTop: 5 },
});
