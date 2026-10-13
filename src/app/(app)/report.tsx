import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { ApiError, analyticsApi, safetyApi, type ReportTarget } from '@/api';
import {
  Avatar, Button, Field, Header, IconButton, IconTile, Note, RadioGroup, Row, Screen, StateBlock, Switch, T, goBack,
} from '@/components/ui';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const PERSON = ['Harassment or unwanted behavior', 'Spam or scams', 'Threatening behavior', 'Inappropriate or sexual content', 'Fake or misleading identity', 'Impersonation', 'Unsafe or suspicious activity', 'Discrimination or hateful behavior', 'Something else'];
const MESSAGE = ['Harassment or unwanted behavior', 'Spam or scams', 'Threatening behavior', 'Inappropriate or sexual content', 'Unsafe or suspicious activity', 'Discrimination or hateful behavior', 'Something else'];

const REASONS: Record<ReportTarget, string[]> = {
  PROFILE: PERSON,
  PARTICIPANT: PERSON,
  MESSAGE,
  CONVERSATION: MESSAGE,
  EVENT: ['Misleading event', 'Unsafe activity', 'Spam or scam', 'Inappropriate content', 'Organizer identity concern', 'Something else'],
  PLAN: ['Misleading information', 'Suspicious activity', 'Unsafe activity', 'Spam', 'Inappropriate content', 'Something else'],
  GROUP: ['Harassment or unwanted behavior', 'Spam or scams', 'Inappropriate or sexual content', 'Unsafe or suspicious activity', 'Something else'],
  ORGANIZER: ['Fake or misleading identity', 'Impersonation', 'Misleading information', 'Spam or scams', 'Something else'],
  PROBLEM: ['A safety concern', 'Something isn’t working', 'Something else'],
};

// Whole titles (not noun substitution) so each language can order words naturally.
const TITLE: Record<ReportTarget, string> = {
  PROFILE: 'Report profile', PARTICIPANT: 'Report participant', MESSAGE: 'Report message', CONVERSATION: 'Report conversation',
  EVENT: 'Report event', PLAN: 'Report Plan', GROUP: 'Report group', ORGANIZER: 'Report organizer', PROBLEM: 'Report a problem',
};

type Step = 'reason' | 'form' | 'done' | 'error' | 'offline' | 'duplicate';

export default function ReportFlow() {
  useLanguage();
  const p = useLocalSearchParams<{ targetType: ReportTarget; targetId?: string; title: string; sub?: string; quote?: string; personId?: string; personName?: string }>();
  const type = p.targetType;
  const personId = p.personId ? Number(p.personId) : null;
  const first = p.personName || tr('this person');

  const [step, setStep] = useState<Step>('reason');
  const [reason, setReason] = useState<string | null>(null);
  const [details, setDetails] = useState('');
  const [blockToo, setBlockToo] = useState(false);
  const [blocked, setBlocked] = useState(false);
  const [busy, setBusy] = useState(false);
  const [existingId, setExistingId] = useState<number | null>(null);

  const submit = async () => {
    if (!reason) return;
    setBusy(true);
    try {
      await safetyApi.report({
        targetType: type, targetId: p.targetId ? Number(p.targetId) : null, reason, details: details.trim() || undefined,
        blockUserId: blockToo ? personId : null,
      });
      setBlocked(blockToo);
      analyticsApi.track('report_submitted', { type, blocked: blockToo });
      setStep('done');
    } catch (e) {
      if (e instanceof ApiError && e.code === 'DUPLICATE_REPORT') {
        setExistingId(e.existingId ?? null);
        setStep('duplicate');
      } else setStep(e instanceof ApiError && e.isNetwork ? 'offline' : 'error');
    } finally {
      setBusy(false);
    }
  };

  const cancel = () => goBack();

  const context = step === 'reason' || step === 'form' ? (
    <View style={styles.ctx} accessibilityLabel={tr('What you are reporting')}>
      {personId ? <Avatar name={p.personName || p.title} id={personId} size={40} /> : <IconTile name={type === 'MESSAGE' || type === 'CONVERSATION' ? 'message-circle' : type === 'PLAN' || type === 'EVENT' ? 'calendar' : 'flag'} />}
      <View style={{ flex: 1 }}>
        <T variant="bodyStrong">{p.title}</T>
        {p.sub ? <T variant="small">{p.sub}</T> : null}
      </View>
      {p.quote ? <Text style={styles.quote}>“{p.quote}”</Text> : null}
    </View>
  ) : null;

  return (
    <Screen edges={['top', 'bottom']}>
      <Header
        title={tr(TITLE[type])}
        center
        onBack={step === 'form' ? () => setStep('reason') : cancel}
        right={<IconButton name="x" label={tr('Cancel report')} onPress={cancel} />}
      />
      {context}

      {step === 'reason' ? (
        <>
          <T variant="title" style={{ marginTop: 18 }}>{tr('What would you like to report?')}</T>
          <T variant="body" style={{ marginBottom: 14 }}>{tr('Choose the closest option.')}</T>
          <RadioGroup label={tr('Report reason')} options={REASONS[type].map((r) => ({ value: r, label: tr(r) }))} value={reason} onChange={setReason} />
          <Button label={tr('Continue')} disabled={!reason} onPress={() => setStep('form')} style={{ marginTop: 18 }} />
        </>
      ) : null}

      {step === 'form' ? (
        <>
          <View style={styles.reason}>
            <Text style={styles.reasonText}>{reason ? tr(reason) : null}</Text>
            <Button label={tr('Change')} kind="text" compact onPress={() => setStep('reason')} />
          </View>
          <Field
            label={tr('Tell us more')}
            optional
            hint={`${details.length}/1000 · Additional context can help us review this report.`}
            value={details}
            onChangeText={setDetails}
            multiline
            maxLength={1000}
            placeholder={tr('What happened? A sentence is enough.')}
          />
          {personId ? (
            <View style={{ backgroundColor: '#fff', borderRadius: 18, borderWidth: 1, borderColor: colors.line, marginBottom: 12 }}>
              <Row first label={tr('Block {first} too', { first })} sub={tr('Reporting and blocking are separate. Off unless you choose.')} right={<Switch value={blockToo} onChange={setBlockToo} label={tr('Block {first} after reporting', { first })} />} />
            </View>
          ) : null}
          <Note icon="lock">{tr('Reports are handled privately.')}{' '}{personId ? tr('{first} won’t be told who reported them.', { first }) : tr('The creator won’t see who reported this.')}</Note>
          <Button label={busy ? tr('Submitting…') : tr('Submit report')} kind="dangerSolid" loading={busy} onPress={submit} style={{ marginTop: 16 }} />
        </>
      ) : null}

      {step === 'done' ? (
        <StateBlock
          icon="check"
          title={tr('Report submitted')}
          body={tr('Thanks for letting us know. We’ll review the report and take appropriate action when needed.{v}', { v: blocked ? tr(' You also blocked {first} — they can’t message you or see your Plans.', { first }) : '' })}
          actions={[
            { label: tr('Done'), onPress: cancel },
            ...(personId && !blocked ? [{ label: tr('Block {first}', { first }), kind: 'secondary' as const, onPress: async () => { await safetyApi.block(personId); setBlocked(true); } }] : []),
            { label: tr('Go to Safety Center'), kind: 'text' as const, onPress: () => router.replace('/safety') },
          ]}
        />
      ) : null}
      {step === 'error' ? (
        <StateBlock icon="refresh-cw" tone="bad" title={tr('Your report couldn’t be submitted')} body={tr('Nothing was sent. Your answers are saved — try again.')} actions={[{ label: tr('Try again'), onPress: submit }]} />
      ) : null}
      {step === 'offline' ? (
        <StateBlock icon="wifi-off" tone="neutral" title={tr('You’re offline')} body={tr('Connect to the internet to submit this report. Nothing has been sent yet.')} actions={[{ label: tr('Try again'), onPress: submit }]} />
      ) : null}
      {step === 'duplicate' ? (
        <StateBlock
          icon="flag"
          tone="neutral"
          title={tr('You’ve already reported this')}
          body={tr('Your earlier report is still open, so there’s no need to send another.')}
          actions={[
            ...(existingId ? [{ label: tr('View report status'), onPress: () => router.replace(`/safety/reports/${existingId}`) }] : []),
            { label: tr('Close'), kind: 'secondary' as const, onPress: cancel },
          ]}
        />
      ) : null}
      {step === 'done' ? <T variant="small" style={{ textAlign: 'center' }}>{tr('If you are in immediate danger, call 112.')}</T> : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  ctx: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: 12, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, padding: 12 },
  quote: { width: '100%', fontFamily: fonts.body, fontStyle: 'italic', fontSize: 12, color: colors.inkSoft, backgroundColor: colors.paper, padding: 8, borderRadius: 10 },
  reason: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.brandPale, borderRadius: 14, paddingLeft: 14, marginVertical: 16 },
  reasonText: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.brandDark, flex: 1 },
});
