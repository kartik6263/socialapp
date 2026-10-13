import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { View } from 'react-native';
import {
  ApiError, analyticsApi, plansApi, type LocationMode, type PlanRequest, type PlanVisibility, type RegistrationMode,
} from '@/api';
import { DateField } from '@/components/DateField';
import {
  Banner, Button, Chip, Field, Header, KeyValue, Loading, Note, Pill, RadioGroup, Row, Screen, SectionTitle, StepBars, Switch, T,
} from '@/components/ui';
import { useMe } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { categoryLabel, useCategories } from '@/lib/categories';
import { planDate } from '@/lib/format';
import { colors } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const TITLES = ['Details', 'When & where', 'People', 'Review'];

interface Form {
  as: 'personal' | 'org';
  official: boolean;
  title: string;
  category: string;
  description: string;
  start: Date | null;
  end: Date | null;
  area: string;
  loc: LocationMode;
  meetingPoint: string;
  limit: string;
  visibility: PlanVisibility;
  regMode: RegistrationMode;
  regUrl: string;
  schedule: string;
  bring: string;
  eligibility: string;
}

export default function CreatePlan() {
  const categories = useCategories();
  useLanguage();
  const me = useMe();
  const toast = useToast();
  const { from, draft } = useLocalSearchParams<{ from?: string; draft?: string }>();
  const orgOk = me.organizer?.status === 'VERIFIED';
  const restricted = me.accountStatus === 'RESTRICTED';

  const [step, setStep] = useState(1);
  const [busy, setBusy] = useState<'publish' | 'draft' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [prefill, setPrefill] = useState<string | null>(null);
  const [loadingPrefill, setLoadingPrefill] = useState(!!(from || draft));
  const [f, setF] = useState<Form>({
    as: 'personal', official: false, title: '', category: '', description: '', start: null, end: null,
    area: me.area ?? '', loc: me.privacy.planLocation === 'PUBLIC_VENUE' ? 'PUBLIC_VENUE' : 'APPROXIMATE', meetingPoint: '',
    limit: '', visibility: me.privacy.defaultPlanVisibility, regMode: 'APP', regUrl: '', schedule: '', bring: '', eligibility: '',
  });
  const set = <K extends keyof Form>(k: K, v: Form[K]) => {
    setF((cur) => ({ ...cur, [k]: v }));
    setError(null);
  };

  useEffect(() => {
    const sourceId = Number(draft ?? from);
    if (!sourceId) return;
    plansApi.get(sourceId).then((p) => {
      setF((cur) => ({
        ...cur,
        as: p.host.kind === 'ORGANIZER' ? 'org' : 'personal', official: p.official, title: draft ? p.title : p.title,
        category: p.category, description: p.description ?? '', area: p.area, loc: p.locationMode, meetingPoint: p.meetingPoint ?? '',
        limit: String(p.participantLimit), visibility: p.visibility, regMode: p.registrationMode, regUrl: p.registrationUrl ?? '',
        schedule: p.schedule.map((s) => `${s.time} ${s.what}`).join('\n'), bring: p.bring ?? '', eligibility: p.eligibility ?? '',
        start: draft && p.startAt ? new Date(p.startAt) : null,
      }));
      setPrefill(draft ? tr('Continuing your draft.') : tr('Details copied from “{title}”. Choose a new date.', { title: p.title }));
    }).catch(() => undefined).finally(() => setLoadingPrefill(false));
  }, [draft, from]);

  const validate = (s: number): string | null => {
    if (s === 1) {
      if (f.title.trim().length < 4) return tr('Give your Plan a title of at least 4 characters.');
      if (!f.category.trim()) return tr('Choose a category.');
    }
    if (s === 2) {
      if (!f.start) return tr('Choose a date and time.');
      if (f.start.getTime() < Date.now()) return tr('Choose a time in the future.');
      if (f.end && f.end <= f.start) return tr('The end must be after the start.');
      if (!f.area.trim()) return tr('Add an approximate area.');
      if (!f.meetingPoint.trim()) return tr('Add a public meeting point.');
      if (/\b(flat|apartment|house no|my home|my place)\b/i.test(f.meetingPoint)) return tr('Meeting points must be public places. Never use a home address.');
    }
    if (s === 3) {
      const n = Number(f.limit);
      if (!Number.isInteger(n) || n < 2 || n > 500) return tr('Set a participant limit between 2 and 500.');
      if (f.regMode === 'EXTERNAL' && !/^(https?:\/\/)?[\w-]+(\.[\w-]+)+/.test(f.regUrl.trim())) return tr('Add a valid registration link.');
    }
    return null;
  };

  const next = () => {
    const err = validate(step);
    if (err) return setError(err);
    setStep(step + 1);
  };

  const toRequest = (isDraft: boolean): PlanRequest => ({
    asOrganizer: f.as === 'org',
    official: f.as === 'org' && f.official,
    title: f.title.trim(),
    category: f.category.trim(),
    description: f.description.trim() || undefined,
    area: f.area.trim(),
    startAt: f.start?.toISOString() ?? null,
    endAt: f.end?.toISOString() ?? null,
    locationMode: f.loc,
    meetingPoint: f.meetingPoint.trim() || undefined,
    participantLimit: Number(f.limit) || 10,
    visibility: f.visibility,
    registrationMode: f.as === 'org' ? f.regMode : 'APP',
    registrationUrl: f.regMode === 'EXTERNAL' ? f.regUrl.trim() : undefined,
    schedule: f.schedule.split('\n').map((l) => l.trim()).filter(Boolean).map((l) => {
      const m = l.match(/^(\d{1,2}(:\d{2})?\s?(AM|PM|am|pm)?)\s+(.*)$/);
      return m ? { time: m[1].toUpperCase(), what: m[4] } : { time: '', what: l };
    }),
    bring: f.bring.trim() || undefined,
    eligibility: f.eligibility.trim() || undefined,
    draft: isDraft,
  });

  const submit = async (isDraft: boolean) => {
    if (!isDraft) {
      for (const s of [1, 2, 3]) {
        const err = validate(s);
        if (err) { setStep(s); return setError(err); }
      }
    } else if (f.title.trim().length < 4) return setError(tr('Add a title to save a draft.'));
    setBusy(isDraft ? 'draft' : 'publish');
    try {
      const body = toRequest(isDraft);
      const plan = draft ? await plansApi.updateDraft(Number(draft), body) : await plansApi.create(body);
      if (!isDraft) analyticsApi.track('plan_created', { official: body.official, category: body.category });
      toast(isDraft ? tr('Draft saved — only you can see it.') : tr('Your Plan is live.'));
      router.replace(`/plan/${plan.id}`);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t save your Plan. Try again.'));
    } finally {
      setBusy(null);
    }
  };

  if (loadingPrefill) return <Screen><Loading /></Screen>;

  if (restricted) {
    return (
      <Screen>
        <Header kicker={tr('CREATE A PLAN')} title={tr('Unavailable')} />
        <Banner icon="lock" tone="warn" title={tr('Creating Plans is paused on your account')} body={tr('Your account has limited access after a review under our community guidelines.')} />
        <Button label={tr('See what’s affected')} kind="secondary" onPress={() => router.replace('/settings/restricted')} style={{ marginTop: 14 }} />
      </Screen>
    );
  }

  return (
    <Screen
      edges={['top', 'bottom']}
      footer={
        <View style={{ flexDirection: 'row', gap: 8, padding: 16, borderTopWidth: 1, borderTopColor: colors.line, backgroundColor: colors.paper }}>
          {step < 4 ? <Button label={tr('Continue')} onPress={next} style={{ flex: 1 }} /> : <Button label={f.official ? tr('Publish event') : tr('Publish Plan')} loading={busy === 'publish'} disabled={!!busy} onPress={() => submit(false)} style={{ flex: 1 }} />}
          <Button label={tr('Save as draft')} kind="secondary" loading={busy === 'draft'} disabled={!!busy} onPress={() => submit(true)} />
        </View>
      }
    >
      <Header kicker={tr('CREATE A PLAN')} title={tr(TITLES[step - 1])} onBack={() => (step > 1 ? setStep(step - 1) : router.back())} />
      <View style={{ marginHorizontal: -16 }}><StepBars total={4} current={step} /></View>
      <T variant="caption" style={{ marginBottom: 12 }}>{tr('Step {step} of 4', { step })}</T>
      {prefill ? <View style={{ marginBottom: 12 }}><Banner icon="copy" tone="neutral" title={prefill} /></View> : null}

      {step === 1 ? (
        <>
          <SectionTitle title={tr('Create as')} />
          <RadioGroup
            label={tr('Create as')}
            value={f.as}
            onChange={(v) => { set('as', v); if (v === 'personal') set('official', false); }}
            options={[
              { value: 'personal', label: tr('Yourself'), sub: tr('A personal Plan from {displayName}', { displayName: me.displayName }) },
              ...(me.organizer ? [{
                value: 'org' as const, label: me.organizer.name, disabled: !orgOk,
                sub: orgOk ? tr('Organizer Plan · Organizer verified') : tr('Available after organizer verification'),
              }] : []),
            ]}
          />
          {f.as === 'org' ? (
            <View style={{ backgroundColor: '#fff', borderRadius: 18, borderWidth: 1, borderColor: colors.line, marginTop: 10 }}>
              <Row first label={tr('Official event')} sub={tr('Shows the Official event badge. Only for events you’re authorised to represent.')} right={<Switch value={f.official} onChange={(v) => set('official', v)} label={tr('Official event')} />} />
            </View>
          ) : null}
          <View style={{ height: 16 }} />
          <Field label={tr('What are you doing?')} value={f.title} onChangeText={(t) => set('title', t)} placeholder={tr('Cubbon Park sunrise walk')} maxLength={80} />
          <T variant="caption" style={{ color: colors.ink, fontSize: 13, fontFamily: 'DMSans_700Bold', marginBottom: 6 }}>{tr('Category')}</T>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 14 }}>
            {categories.map((c) => <Chip key={c.name} label={categoryLabel(c.name)} selected={f.category === c.name} onPress={() => set('category', c.name)} />)}
          </View>
          <Field label={tr('Description')} optional value={f.description} onChangeText={(t) => set('description', t)} multiline maxLength={1500} placeholder={tr('What you’ll do and who it’s for')} />
        </>
      ) : null}

      {step === 2 ? (
        <>
          <DateField label={tr('Starts')} value={f.start} onChange={(d) => set('start', d)} minimumDate={new Date()} />
          <DateField label={tr('Ends')} optional value={f.end} onChange={(d) => set('end', d)} minimumDate={f.start ?? new Date()} />
          <Field label={tr('Area')} value={f.area} onChangeText={(t) => set('area', t)} placeholder={tr('Indiranagar, Bengaluru')} hint={tr('Shown to everyone as an approximate area.')} />
          <SectionTitle title={tr('Location')} />
          <RadioGroup
            label={tr('Location type')}
            value={f.loc}
            onChange={(v) => set('loc', v)}
            options={[
              { value: 'APPROXIMATE', label: tr('Approximate area until people join'), sub: tr('Participants see the exact public meeting point after joining') },
              { value: 'PUBLIC_VENUE', label: tr('Public venue'), sub: tr('Shown to everyone — only for public places') },
              ...(f.official ? [{ value: 'OFFICIAL_VENUE' as const, label: tr('Official event venue'), sub: tr('The event’s published venue') }] : []),
            ]}
          />
          <View style={{ height: 14 }} />
          <Field
            label={f.loc === 'APPROXIMATE' ? tr('Meeting point (shared after joining)') : tr('Venue')}
            value={f.meetingPoint}
            onChangeText={(t) => set('meetingPoint', t)}
            placeholder={tr('Cubbon Park, bandstand')}
            hint={tr('Meeting points must be public places. Never use a home address.')}
          />
        </>
      ) : null}

      {step === 3 ? (
        <>
          <Field label={tr('Participant limit')} value={f.limit} onChangeText={(t) => set('limit', t.replace(/\D/g, ''))} keyboardType="number-pad" placeholder="12" hint={tr('Including you.')} />
          <SectionTitle title={tr('Visibility')} />
          <RadioGroup
            label={tr('Visibility')}
            value={f.visibility}
            onChange={(v) => set('visibility', v)}
            options={[
              { value: 'DISCOVERABLE', label: tr('Discoverable'), sub: tr('Can appear in relevant discovery results nearby.') },
              { value: 'SHARED_CONTEXT', label: tr('Shared-context only'), sub: tr('Only people with a shared event, destination or connection can find it.') },
              { value: 'PRIVATE', label: tr('Private link'), sub: tr('Not publicly discoverable. Only people with the link can join.') },
            ]}
          />
          {f.as === 'org' ? (
            <>
              <SectionTitle title={tr('Registration')} />
              <RadioGroup
                label={tr('Registration')}
                value={f.regMode}
                onChange={(v) => set('regMode', v)}
                options={[
                  { value: 'APP', label: tr('Join in the app'), sub: tr('People join the Plan here') },
                  { value: 'EXTERNAL', label: tr('External registration required'), sub: tr('People also register on your site') },
                ]}
              />
              {f.regMode === 'EXTERNAL' ? (
                <View style={{ marginTop: 14 }}>
                  <Field label={tr('Registration link')} value={f.regUrl} onChangeText={(t) => set('regUrl', t)} autoCapitalize="none" keyboardType="url" placeholder={tr('https://')} hint={tr('Plans doesn’t sell tickets or take payments.')} />
                </View>
              ) : null}
              <View style={{ height: 14 }} />
              <Field label={tr('Schedule')} optional value={f.schedule} onChangeText={(t) => set('schedule', t)} multiline placeholder={tr('One item per line, e.g.\n7:00 AM Meet at the bandstand')} />
            </>
          ) : <View style={{ height: 14 }} />}
          <Field label={tr('What to bring')} optional value={f.bring} onChangeText={(t) => set('bring', t)} placeholder={tr('Water, comfortable shoes')} />
          <Field label={tr('Who can join')} optional value={f.eligibility} onChangeText={(t) => set('eligibility', t)} placeholder={tr('Beginners welcome · 18+')} />
        </>
      ) : null}

      {step === 4 ? (
        <>
          {f.official ? <View style={{ marginBottom: 10 }}><Pill label={tr('Official event')} icon="calendar" tone="ok" /></View> : null}
          <KeyValue
            rows={[
              { k: tr('Host'), v: f.as === 'org' ? me.organizer?.name ?? '' : me.displayName },
              { k: tr('Title'), v: f.title },
              { k: tr('Category'), v: categoryLabel(f.category) },
              { k: tr('When'), v: f.start ? planDate(f.start.toISOString(), f.end?.toISOString()) : tr('Not set') },
              { k: tr('Area'), v: tr('{area} · approximate', { area: f.area }) },
              { k: f.loc === 'APPROXIMATE' ? tr('Meeting point') : tr('Venue'), v: `${f.meetingPoint}${f.loc === 'APPROXIMATE' ? tr(' (after joining)') : ''}` },
              { k: tr('Limit'), v: tr('{n} people', { n: f.limit }) },
              { k: tr('Visibility'), v: { DISCOVERABLE: tr('Discoverable'), SHARED_CONTEXT: tr('Shared-context only'), PRIVATE: tr('Private link') }[f.visibility] },
              ...(f.as === 'org' ? [{ k: tr('Registration'), v: f.regMode === 'APP' ? tr('In the app') : tr('External · {regUrl}', { regUrl: f.regUrl }) }] : []),
            ]}
          />
          <Button label={tr('Edit')} kind="text" onPress={() => setStep(1)} style={{ alignSelf: 'flex-start' }} />
          <Note icon="shield">{tr('A Plan Group opens for participants automatically. Phone numbers are never shared.')}</Note>
        </>
      ) : null}

      {error ? <View style={{ marginTop: 12 }}><Banner icon="alert-circle" tone="bad" title={error} /></View> : null}
    </Screen>
  );
}
