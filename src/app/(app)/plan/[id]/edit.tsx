import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { View } from 'react-native';
import { ApiError, plansApi, type PlanDetail } from '@/api';
import { DateField } from '@/components/DateField';
import { Banner, Button, Diff, Field, Header, Loading, Row, Screen, Switch, T } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { planDate } from '@/lib/format';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

/** Edit event details. Time/place changes always notify participants with exactly what changed. */
export default function EditDetails() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const toast = useToast();
  const [plan, setPlan] = useState<PlanDetail | null>(null);
  const [start, setStart] = useState<Date | null>(null);
  const [meet, setMeet] = useState('');
  const [limit, setLimit] = useState('');
  const [instructions, setInstructions] = useState('');
  const [notify, setNotify] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    plansApi.get(Number(id)).then((p) => {
      setPlan(p);
      setStart(p.startAt ? new Date(p.startAt) : null);
      setMeet(p.meetingPoint ?? '');
      setLimit(String(p.participantLimit));
      setInstructions(p.instructions ?? '');
    }).catch((e) => setError(e instanceof ApiError ? e.message : tr('Couldn’t load this Plan.')));
  }, [id]);

  const changes = useMemo(() => {
    if (!plan) return [];
    const out: { label: string; from: string; to: string }[] = [];
    if (start && plan.startAt && start.getTime() !== new Date(plan.startAt).getTime()) out.push({ label: tr('Date & time'), from: planDate(plan.startAt), to: planDate(start.toISOString()) });
    if (meet.trim() !== (plan.meetingPoint ?? '')) out.push({ label: tr('Meeting point'), from: plan.meetingPoint ?? '—', to: meet.trim() });
    if (Number(limit) !== plan.participantLimit) out.push({ label: tr('Participant limit'), from: String(plan.participantLimit), to: limit });
    if (instructions.trim() !== (plan.instructions ?? '')) out.push({ label: tr('Instructions'), from: plan.instructions ? tr('Previous') : '—', to: tr('Updated') });
    return out;
  }, [plan, start, meet, limit, instructions]);

  // Time and location changes always notify — participants must never miss them.
  const mustNotify = changes.some((c) => c.label === 'Date & time' || c.label === 'Meeting point');

  if (!plan) return <Screen><Header kicker={tr('EDIT')} title={tr('Edit details')} />{error ? <Banner icon="alert-circle" tone="bad" title={error} /> : <Loading />}</Screen>;

  const save = async () => {
    const n = Number(limit);
    if (!Number.isInteger(n) || n < Math.max(2, plan.participantCount)) return setError(tr('The limit can’t be lower than the {participantCount} people who already joined.', { participantCount: plan.participantCount }));
    if (!meet.trim()) return setError(tr('Add a public meeting point.'));
    setBusy(true);
    setError(null);
    try {
      await plansApi.updateDetails(plan.id, {
        startAt: start?.toISOString() ?? null, meetingPoint: meet.trim(), participantLimit: n, instructions: instructions.trim(), notify: notify || mustNotify,
      });
      toast(notify || mustNotify ? tr('Saved. Participants were notified.') : tr('Saved.'));
      router.back();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Header kicker={plan.title.toUpperCase()} title={tr('Edit details')} />
      <T variant="body" style={{ marginBottom: 16 }}>{tr('Changes update the Plan for everyone. Participants see exactly what changed.')}</T>
      <DateField label={tr('Date & time')} value={start} onChange={setStart} minimumDate={new Date()} />
      <Field label={tr('Meeting point')} value={meet} onChangeText={setMeet} hint={tr('Public places only.')} />
      <Field label={tr('Participant limit')} value={limit} onChangeText={(t) => setLimit(t.replace(/\D/g, ''))} keyboardType="number-pad" />
      <Field label={tr('Instructions for participants')} optional value={instructions} onChangeText={setInstructions} multiline maxLength={600} />
      <View style={{ backgroundColor: '#fff', borderRadius: 18, borderWidth: 1, borderColor: colors.line }}>
        <Row first label={tr('Notify participants')} sub={tr('On for time and location changes. They get one notification with what changed.')} right={<Switch value={notify || mustNotify} disabled={mustNotify} onChange={setNotify} label={tr('Notify participants')} />} />
      </View>
      {changes.length ? <View style={{ marginTop: 14 }}><Diff changes={changes} /></View> : null}
      {error ? <View style={{ marginTop: 12 }}><Banner icon="alert-circle" tone="bad" title={error} /></View> : null}
      <Button label={tr('Save changes')} disabled={!changes.length} loading={busy} onPress={save} style={{ marginTop: 16 }} />
    </Screen>
  );
}
