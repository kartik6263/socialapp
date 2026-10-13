import { View } from 'react-native';
import { EmergencyNote, Group, Header, Icon, Screen, SectionTitle, T } from '@/components/ui';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const SECTIONS: [string, string[]][] = [
  ['Before meeting', [
    'Review the person’s profile and the Plan details',
    'Keep your phone number, address and other private details private',
    'Choose a public meeting place',
    'Tell someone you trust where you’re going',
  ]],
  ['During the activity', [
    'Trust your judgement',
    'You can leave a Plan at any time',
    'You can block or report someone from their profile, a chat or the group',
  ]],
  ['If something feels wrong', [
    'Leave the situation',
    'Block the person',
    'Report what happened — reports are private',
  ]],
];

export default function Guidelines() {
  useLanguage();
  return (
    <Screen>
      <Header kicker={tr('SAFETY CENTER')} title={tr('Safety guidelines')} />
      <T variant="body">{tr('Most Plans go exactly as planned. These habits help when meeting people for the first time.')}</T>
      {SECTIONS.map(([title, items]) => (
        <View key={title}>
          <SectionTitle title={tr(title)} />
          <Group>
            {items.map((text, i) => (
              <View key={text} style={{ flexDirection: 'row', gap: 10, padding: 13, borderTopWidth: i ? 1 : 0, borderTopColor: colors.divider }}>
                <Icon name="check" size={15} color={colors.brand} />
                <T variant="small" style={{ flex: 1, color: colors.ink }}>{tr(text)}</T>
              </View>
            ))}
          </Group>
        </View>
      ))}
      <View style={{ marginTop: 18 }}><EmergencyNote /></View>
      <T variant="small" style={{ marginTop: 12 }}>
        {tr('Verification and reports help, but Plans can’t guarantee anyone’s behaviour or your personal safety. You decide who to meet and when to leave.')}
      </T>
    </Screen>
  );
}
