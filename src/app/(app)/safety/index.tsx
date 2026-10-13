import { router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { safetyApi } from '@/api';
import { EmergencyNote, ErrorBlock, Group, Header, Icon, IconTile, Row, Screen, SectionTitle, Skeleton, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { openReport } from '@/lib/report';
import { STATUS_LABEL } from '@/lib/reports';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const TIPS = [
  ['users', 'Share your Plan with someone you trust'],
  ['map-pin', 'Meet in public places'],
  ['lock', 'Keep private information private'],
  ['flag', 'Leave or report if something feels wrong'],
] as const;

export default function SafetyCenter() {
  useLanguage();
  const { data, error, loading, refresh } = useFocusData(async () => {
    const [reports, blocked] = await Promise.all([safetyApi.reports(), safetyApi.blocked()]);
    return { reports, blocked };
  });

  const fresh = data?.reports.find((r) => r.unseenUpdate);
  const latest = data?.reports[0];

  return (
    <Screen>
      <Header kicker={tr('SETTINGS')} title={tr('Safety Center')} />
      <T variant="body">{tr('Tools and information to help you stay safe while meeting people through Plans.')}</T>
      {loading ? <Skeleton rows={4} /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} title={tr('Couldn’t load Safety Center')} /> : data ? (
        <>
          <Pressable
            onPress={() => fresh && router.push(`/safety/reports/${fresh.id}`)}
            disabled={!fresh}
            style={[styles.attn, fresh && { backgroundColor: colors.brandPale, borderColor: '#bcd9cc' }]}
            accessibilityRole={fresh ? 'button' : 'text'}
          >
            <IconTile name={fresh ? 'bell' : 'check'} tone={fresh ? 'ok' : 'neutral'} />
            <View style={{ flex: 1 }}>
              <T variant="bodyStrong">{fresh ? tr('1 report has an update') : tr('Nothing needs your attention right now')}</T>
              <T variant="small">{fresh ? `${fresh.targetLabel} · ${tr(STATUS_LABEL[fresh.status])}` : tr('Your safety tools are below whenever you need them.')}</T>
            </View>
            {fresh ? <Icon name="chevron-right" size={16} color={colors.inkSoft} /> : null}
          </Pressable>

          <SectionTitle title={tr('Your safety tools')} />
          <Group>
            <Row first icon="lock" label={tr('Blocked people')} sub={data.blocked.length ? `${data.blocked.length} ${data.blocked.length === 1 ? 'person' : 'people'}` : tr('No one blocked')} onPress={() => router.push('/safety/blocked')} />
            <Row icon="flag" label={tr('Your reports')} sub={latest ? tr('{v} submitted · latest {v2}', { v: data.reports.length, v2: tr(STATUS_LABEL[latest.status]).toLowerCase() }) : tr('None submitted')} onPress={() => router.push('/safety/reports')} />
            <Row icon="eye" label={tr('Privacy controls')} sub={tr('Control what other people can see')} onPress={() => router.push('/safety/visibility')} />
            <Row icon="check" label={tr('Verification')} sub={tr('What verification means — and doesn’t')} onPress={() => router.push('/verify')} />
            <Row icon="settings" label={tr('Account security')} sub={tr('Sign-in alerts and devices')} onPress={() => router.push('/settings/security')} />
          </Group>

          <SectionTitle title={tr('While meeting someone')} />
          <Group>
            {TIPS.map(([icon, text], i) => (
              <View key={text} style={[styles.tip, i > 0 && { borderTopWidth: 1, borderTopColor: colors.divider }]}>
                <Icon name={icon} size={16} color={colors.brand} />
                <T variant="small" style={{ color: colors.ink, flex: 1 }}>{tr(text)}</T>
              </View>
            ))}
            <Row label={tr('Read safety guidelines')} onPress={() => router.push('/safety/guidelines')} />
          </Group>

          <SectionTitle title={tr('Help')} />
          <Group>
            <Row first icon="flag" label={tr('Report a problem')} sub={tr('Something wrong that isn’t about one person or Plan')} onPress={() => openReport({ targetType: 'PROBLEM', title: tr('A problem with Plans') })} />
            <Row icon="shield" label={tr('Safety guidelines')} sub={tr('Before, during and after a Plan')} onPress={() => router.push('/safety/guidelines')} />
            <Row icon="message-circle" label={tr('Contact support')} sub={tr('Talk to our support team')} onPress={() => router.push('/help')} />
          </Group>
          <View style={{ marginTop: 16 }}><EmergencyNote /></View>
        </>
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  attn: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, borderRadius: 18, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.surface, marginTop: 16 },
  tip: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 13 },
});
