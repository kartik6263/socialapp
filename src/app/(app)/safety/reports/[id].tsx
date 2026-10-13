import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { safetyApi } from '@/api';
import { ConfirmDialog } from '@/components/Sheet';
import { Banner, Button, ErrorBlock, Header, IconTile, KeyValue, Loading, Pill, Screen, SectionTitle, T } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useFocusData } from '@/hooks/useAsync';
import { relativeTime } from '@/lib/format';
import { OUTCOME, STATUS_LABEL, STATUS_TONE, TYPE_ICON, TYPE_LABEL } from '@/lib/reports';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function ReportDetail() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const toast = useToast();
  const { data: r, error, loading, refresh } = useFocusData(() => safetyApi.reportDetail(Number(id)), [id]);
  const [confirm, setConfirm] = useState(false);
  const [blocked, setBlocked] = useState(false);

  if (loading) return <Screen><Header kicker={tr('YOUR REPORTS')} title={tr('Report details')} /><Loading /></Screen>;
  if (!r) return <Screen><Header kicker={tr('YOUR REPORTS')} title={tr('Report details')} />{error ? <ErrorBlock error={error} onRetry={refresh} /> : null}</Screen>;

  const final = r.status === 'ACTION_TAKEN' || r.status === 'NO_ACTION' || r.status === 'CLOSED';
  const steps = [
    { label: tr('Submitted'), note: relativeTime(r.submittedAt), done: true },
    { label: tr('Under review'), note: r.status === 'SUBMITTED' ? tr('Waiting') : tr('Reviewed by our team'), done: r.status !== 'SUBMITTED' },
    { label: final ? tr(STATUS_LABEL[r.status]) : tr('Outcome'), note: final ? relativeTime(r.updatedAt) : tr('We’ll notify you'), done: final },
  ];

  return (
    <Screen>
      <Header kicker={tr('YOUR REPORTS')} title={tr('Report details')} />
      <View style={styles.card}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <IconTile name={TYPE_ICON[r.targetType]} tone="neutral" />
          <Pill label={tr(STATUS_LABEL[r.status])} tone={STATUS_TONE[r.status]} />
        </View>
        <T variant="heading" style={{ marginVertical: 10 }}>{r.targetLabel}</T>
        <KeyValue rows={[{ k: tr('Type'), v: tr(TYPE_LABEL[r.targetType]) }, { k: tr('Reason'), v: r.reason }, { k: tr('Submitted'), v: relativeTime(r.submittedAt) }]} />
        {r.details ? (
          <View style={{ marginTop: 10 }}>
            <T variant="kicker" style={{ color: colors.inkSoft }}>{tr('WHAT YOU TOLD US')}</T>
            <T variant="body" style={{ marginTop: 4 }}>{r.details}</T>
          </View>
        ) : null}
      </View>

      <SectionTitle title={tr('Status')} />
      <View accessibilityLabel={tr('Report status')}>
        {steps.map((s, i) => (
          <View key={s.label} style={{ flexDirection: 'row', gap: 12 }}>
            <View style={{ alignItems: 'center' }}>
              <View style={[styles.mark, s.done && { backgroundColor: colors.brand, borderColor: colors.brand }]}>
                <Text style={{ color: s.done ? '#fff' : colors.inkSoft, fontFamily: fonts.bodyBold, fontSize: 11 }}>{s.done ? '✓' : i + 1}</Text>
              </View>
              {i < steps.length - 1 ? <View style={[styles.line, s.done && { backgroundColor: colors.brand }]} /> : null}
            </View>
            <View style={{ paddingBottom: 16 }}>
              <T variant="bodyStrong">{s.label}</T>
              <T variant="small">{s.note}</T>
            </View>
          </View>
        ))}
      </View>
      <Banner icon="info" tone={STATUS_TONE[r.status]} title={tr(OUTCOME[r.status])} />
      <T variant="small" style={{ marginTop: 12 }}>{tr('We don’t share details about actions taken on other people’s accounts, and they aren’t told who reported them.')}</T>
      {r.personId && !blocked ? (
        <Button label={tr('Block {v}', { v: r.personName ?? tr('this person') })} kind="secondary" icon="slash" onPress={() => setConfirm(true)} style={{ marginTop: 16 }} />
      ) : null}
      <ConfirmDialog
        visible={confirm}
        onClose={() => setConfirm(false)}
        title={tr('Block {v}?', { v: r.personName ?? tr('this person') })}
        body={tr('They won’t be able to message you, send requests or see your Plans. They won’t be told.')}
        okLabel={tr('Block')} okKind="dangerSolid" icon="slash" tone="bad"
        onConfirm={async () => { await safetyApi.block(r.personId!); setBlocked(true); toast(tr('Blocked')); }}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 20, padding: 14 },
  mark: { width: 24, height: 24, borderRadius: 12, borderWidth: 1.5, borderColor: colors.line, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surface },
  line: { width: 2, flex: 1, backgroundColor: colors.line, marginVertical: 2 },
});
