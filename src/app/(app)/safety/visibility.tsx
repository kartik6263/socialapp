import { router } from 'expo-router';
import { View } from 'react-native';
import { Button, Chip, Group, Header, IconTile, Screen, T, type IconName } from '@/components/ui';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const GROUPS: { icon: IconName; title: string; items: string[] }[] = [
  { icon: 'eye', title: 'People discovering your Plans', items: ['First name', 'Age range', 'Approximate area', 'Interests', 'Verification signals'] },
  { icon: 'users', title: 'Only people in the same Plan', items: ['Plans you’ve joined', 'Connection intent', 'Group messages'] },
  { icon: 'lock', title: 'Never shown to anyone', items: ['Exact home address', 'Live location', 'Phone number', 'Email', 'Verification documents'] },
];

export default function WhatOthersSee() {
  useLanguage();
  return (
    <Screen>
      <Header kicker={tr('PRIVACY')} title={tr('What others can see')} />
      <T variant="body">{tr('Plans shares context, not personal details.')}</T>
      <View style={{ gap: 10, marginTop: 14 }}>
        {GROUPS.map((g) => (
          <Group key={g.title} style={{ padding: 14 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <IconTile name={g.icon} size={32} tone={g.icon === 'lock' ? 'neutral' : 'ok'} />
              <T variant="bodyStrong">{tr(g.title)}</T>
            </View>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}>
              {g.items.map((i) => <Chip key={i} label={tr(i)} />)}
            </View>
          </Group>
        ))}
      </View>
      <View style={{ backgroundColor: colors.brandPale, borderRadius: 16, padding: 14, marginTop: 14 }}>
        <T variant="small" style={{ color: colors.brandDark }}>
          <T variant="small" style={{ fontFamily: 'DMSans_700Bold', color: colors.brandDark }}>{tr('Why approximate area?')}{' '}</T>
          {tr('People only need a rough idea of where you are to find a shared Plan. Meeting points are always public places chosen per Plan.')}
        </T>
      </View>
      <Button label={tr('Manage privacy settings')} onPress={() => router.push('/settings/privacy')} style={{ marginTop: 16 }} />
    </Screen>
  );
}
