import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import type { PrivacySettings } from '@/api';
import { SaveErrorBanner } from '@/components/SaveErrorBanner';
import { Button, Header, RadioGroup, Screen, T } from '@/components/ui';
import { useSavePrivacy } from '@/hooks/useSavePrivacy';
import { tr, useT, type Lang } from '@/i18n';
import { CHOICES, type ChoiceKey } from '@/lib/privacyChoices';

export default function ChoiceScreen() {
  const { setLang } = useT();
  const { key } = useLocalSearchParams<{ key: ChoiceKey }>();
  const def = CHOICES[key];
  const { save, saveError, privacy } = useSavePrivacy();
  const current = privacy[key] as string;
  const [value, setValue] = useState(current);
  const [busy, setBusy] = useState(false);

  if (!def) return null;

  const submit = async () => {
    setBusy(true);
    const ok = await save({ [key]: value } as Partial<PrivacySettings>, tr('{setting} updated', { setting: tr(def.title).replace(/[?？]$/, '') }));
    setBusy(false);
    if (!ok) return;
    if (key === 'language') setLang(value as Lang); // switch the app immediately
    router.back();
  };

  return (
    <Screen>
      <Header kicker={tr(def.kicker)} title={tr(def.title)} />
      <SaveErrorBanner error={saveError} />
      <T variant="body" style={{ marginBottom: 14 }}>{tr(def.intro)}</T>
      <RadioGroup
        label={tr(def.title)}
        options={def.opts.map((o) => ({
          value: o.value,
          // Language names are always shown in their own script, with the English name as the subtitle.
          label: key === 'language' ? o.label : tr(o.label),
          sub: o.sub ? tr(o.sub) : undefined,
        }))}
        value={value}
        onChange={setValue}
      />
      {def.note ? <T variant="small" style={{ marginTop: 10 }}>{tr(def.note)}</T> : null}
      <Button label={tr('Save')} disabled={value === current} loading={busy} onPress={submit} style={{ marginTop: 18 }} />
    </Screen>
  );
}
