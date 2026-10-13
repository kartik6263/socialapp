import { router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { safetyApi } from '@/api';
import { ErrorBlock, Header, IconTile, Note, Pill, Screen, Skeleton, StateBlock, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { relativeTime } from '@/lib/format';
import { STATUS_LABEL, STATUS_TONE, TYPE_ICON, TYPE_LABEL } from '@/lib/reports';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function YourReports() {
  useLanguage();
  const { data, error, loading, refresh } = useFocusData(() => safetyApi.reports());
  return (
    <Screen>
      <Header kicker={tr('SAFETY CENTER')} title={tr('Your reports')} />
      <Note icon="lock">{tr('Reports are handled privately. People you report aren’t told who reported them.')}</Note>
      {loading ? <Skeleton /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : !data?.length ? (
        <StateBlock icon="flag" tone="neutral" title={tr('You haven’t submitted any reports')} body={tr('If something feels wrong, use Report from a profile, Plan, message or group.')} />
      ) : (
        <View style={{ gap: 8, marginTop: 14 }}>
          {data.map((r) => (
            <Pressable
              key={r.id}
              onPress={() => router.push(`/safety/reports/${r.id}`)}
              accessibilityRole="button"
              accessibilityLabel={tr('{v} report, {targetLabel}, status {v2}', { v: tr(TYPE_LABEL[r.targetType]), targetLabel: r.targetLabel, v2: tr(STATUS_LABEL[r.status]) })}
              style={styles.item}
            >
              <IconTile name={TYPE_ICON[r.targetType]} tone="neutral" />
              <View style={{ flex: 1, gap: 3 }}>
                <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
                  <T variant="kicker" style={{ color: colors.inkSoft }}>{tr(TYPE_LABEL[r.targetType]).toUpperCase()}</T>
                  <Pill label={tr(STATUS_LABEL[r.status])} tone={STATUS_TONE[r.status]} />
                </View>
                <T variant="bodyStrong">{r.targetLabel}</T>
                <T variant="small">{r.reason} · {relativeTime(r.submittedAt)}</T>
                {r.unseenUpdate ? <T variant="caption" style={{ color: colors.brand, fontFamily: fonts.bodyBold }}>{tr('● Updated')}</T> : null}
              </View>
            </Pressable>
          ))}
        </View>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  item: { flexDirection: 'row', gap: 12, padding: 14, borderRadius: 18, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.surface },
});
