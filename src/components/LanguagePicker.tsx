import { Pressable, StyleSheet, Text, View } from 'react-native';
import { LANGUAGES, useT } from '@/i18n';
import { colors, fonts } from '@/theme';

/** Compact language switch for screens shown before sign-in. Names are always in their own script. */
export function LanguagePicker() {
  const { lang, setLang } = useT();
  return (
    <View style={styles.row} accessibilityRole="radiogroup" accessibilityLabel="Language / भाषा / ಭಾಷೆ">
      {LANGUAGES.map((l) => {
        const on = l.value === lang;
        return (
          <Pressable
            key={l.value}
            onPress={() => setLang(l.value)}
            accessibilityRole="radio"
            accessibilityState={{ checked: on }}
            accessibilityLabel={l.secondary ? `${l.label} (${l.english}, secondary)` : `${l.label} (${l.english})`}
            style={[styles.item, on && styles.on]}
          >
            <Text style={[styles.text, on && { color: colors.brandDark }]}>{l.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 6, alignSelf: 'flex-start' },
  item: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.surface },
  on: { borderColor: colors.brand, backgroundColor: colors.brandPale },
  text: { fontFamily: fonts.bodySemi, fontSize: 13, color: colors.inkSoft },
});
