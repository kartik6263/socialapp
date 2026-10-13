import * as WebBrowser from 'expo-web-browser';
import { Linking, Text, View, type TextStyle } from 'react-native';
import { colors, fonts } from '@/theme';

/**
 * Just enough Markdown for policy pages edited in the Admin Console: #, ##, ### headings, paragraphs, "- " lists,
 * **bold**, _italic_ and [links](https://…). Headings are marked as headers so screen readers can jump between them.
 */
export function Markdown({ text }: { text: string }) {
  const blocks = text.replace(/\r/g, '').split(/\n{2,}/);
  return (
    <View style={{ gap: 12 }}>
      {blocks.map((block, i) => {
        const b = block.trim();
        if (!b) return null;
        const h = /^(#{1,3})\s+(.*)$/.exec(b);
        if (h) {
          const level = h[1].length;
          return (
            <Text key={i} accessibilityRole="header" style={[styles.h, level === 1 ? styles.h1 : level === 2 ? styles.h2 : styles.h3]}>
              {inline(h[2])}
            </Text>
          );
        }
        const lines = b.split('\n');
        if (lines.every((l) => /^\s*[-*]\s+/.test(l))) {
          return (
            <View key={i} style={{ gap: 8 }}>
              {lines.map((l, j) => (
                <View key={j} style={{ flexDirection: 'row', gap: 10 }}>
                  <Text style={styles.p} importantForAccessibility="no">•</Text>
                  <Text style={[styles.p, { flex: 1 }]}>{inline(l.replace(/^\s*[-*]\s+/, ''))}</Text>
                </View>
              ))}
            </View>
          );
        }
        return <Text key={i} style={styles.p}>{inline(lines.join(' '))}</Text>;
      })}
    </View>
  );
}

function open(url: string) {
  if (url.startsWith('mailto:') || url.startsWith('tel:')) void Linking.openURL(url);
  else if (url.startsWith('https://')) void WebBrowser.openBrowserAsync(url);
}

/** Bold, italic and links inside a line. */
function inline(s: string) {
  const out: (string | React.ReactElement)[] = [];
  const re = /\*\*(.+?)\*\*|_(.+?)_|\[(.+?)\]\(((?:https:\/\/|mailto:|tel:)[^)\s]+)\)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let k = 0;
  while ((m = re.exec(s))) {
    if (m.index > last) out.push(s.slice(last, m.index));
    if (m[1]) out.push(<Text key={k++} style={styles.b}>{m[1]}</Text>);
    else if (m[2]) out.push(<Text key={k++} style={styles.i}>{m[2]}</Text>);
    else {
      const url = m[4];
      out.push(
        <Text key={k++} style={styles.a} accessibilityRole="link" onPress={() => open(url)}>{m[3]}</Text>,
      );
    }
    last = re.lastIndex;
  }
  if (last < s.length) out.push(s.slice(last));
  return out;
}

const styles: Record<string, TextStyle> = {
  h: { fontFamily: fonts.display, color: colors.ink, letterSpacing: -0.4 },
  h1: { fontSize: 24, lineHeight: 29, marginTop: 4 },
  h2: { fontSize: 18, lineHeight: 23, marginTop: 10 },
  h3: { fontSize: 15, lineHeight: 20, marginTop: 6 },
  p: { fontFamily: fonts.body, fontSize: 15, lineHeight: 23, color: colors.inkSoft },
  b: { fontFamily: fonts.bodyBold, color: colors.ink },
  i: { fontStyle: 'italic' },
  a: { fontFamily: fonts.bodyBold, color: colors.brand, textDecorationLine: 'underline' },
};
