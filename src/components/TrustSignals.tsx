import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import type { Signal } from '@/api/types';
import { signalLabel, sortSignals } from '@/lib/format';
import { colors } from '@/theme';
import { Sheet } from './Sheet';
import { Button, Icon, IconTile, Pill, T } from './ui';
import { tr, useLanguage } from '@/i18n';

type Explain = { kind: 'signal'; signal: Signal } | { kind: 'about' } | { kind: 'unavailable' };

const SIGNAL_ICON: Record<Signal, 'shield' | 'check' | 'calendar'> = {
  IDENTITY: 'shield', ORGANIZER: 'shield', OFFICIAL: 'calendar', PHONE: 'check', EMAIL: 'check',
};

const MEANS: Record<Signal, (name?: string) => string> = {
  IDENTITY: (n) => n
    ? tr('{name} completed the identity verification process supported by Plans. The ID matched the name and age range on the profile.', { name: n })
    : tr('This person completed the identity verification process supported by Plans. The ID matched the name and age range on the profile.'),
  PHONE: (n) => n
    ? tr('{name} confirmed ownership of a phone number with a one-time code. The number itself is never shown.', { name: n })
    : tr('They confirmed ownership of a phone number with a one-time code. The number itself is never shown.'),
  EMAIL: (n) => n
    ? tr('{name} confirmed ownership of an email address. The address itself is never shown.', { name: n })
    : tr('They confirmed ownership of an email address. The address itself is never shown.'),
  ORGANIZER: (n) => n
    ? tr('{name} completed the verification required for this organizer type: name, official contact domain and public presence were checked.', { name: n })
    : tr('This organizer completed the verification required for this organizer type: name, official contact domain and public presence were checked.'),
  OFFICIAL: () => tr('This event is represented by a verified organizer, through their official organizer account.'),
};

const NOT: Record<Signal, string> = {
  IDENTITY: 'Verification doesn’t guarantee someone’s behaviour, intentions or safety.',
  PHONE: 'It doesn’t confirm who someone is, or anything about their behaviour.',
  EMAIL: 'It doesn’t confirm who someone is, or anything about their behaviour.',
  ORGANIZER: 'Verification doesn’t guarantee the quality, safety or outcome of an event, or vouch for each attendee.',
  OFFICIAL: 'It doesn’t verify every attendee, or guarantee safety at the event.',
};

export const signalMeaning = (s: Signal) => MEANS[s]().split('. ')[0] + '.';

/**
 * Tappable factual signals ("Identity verified", "Phone verified").
 * Shows nothing when status is unavailable rather than a stale signal.
 */
export function TrustSignals({ signals, name, unavailable, compact }: { signals: Signal[]; name?: string; unavailable?: boolean; compact?: boolean }) {
  useLanguage();
  const [explain, setExplain] = useState<Explain | null>(null);
  const sorted = sortSignals(signals);
  const shown = compact ? sorted.slice(0, 1) : sorted;

  return (
    <>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }} accessibilityLabel={tr('Trust signals')}>
        {unavailable ? (
          <Pill label={tr('Verification status unavailable')} icon="clock" tone="neutral" onPress={() => setExplain({ kind: 'unavailable' })} />
        ) : (
          shown.map((s) => (
            <Pill
              key={s}
              label={signalLabel(s)}
              icon={SIGNAL_ICON[s]}
              tone={s === 'IDENTITY' || s === 'ORGANIZER' || s === 'OFFICIAL' ? 'ok' : 'neutral'}
              onPress={() => setExplain({ kind: 'signal', signal: s })}
              accessibilityLabel={tr('{v}. Learn what this means', { v: signalLabel(s) })}
            />
          ))
        )}
      </View>
      <SignalExplainer explain={explain} name={name} onClose={() => setExplain(null)} />
    </>
  );
}

export function SignalExplainer({ explain, name, onClose }: { explain: Explain | null; name?: string; onClose: () => void }) {
  useLanguage();
  const [about, setAbout] = useState(false);
  const current: Explain | null = about ? { kind: 'about' } : explain;
  const close = () => {
    setAbout(false);
    onClose();
  };

  let kicker = tr('TRUST SIGNAL');
  let title = '';
  let icon: 'shield' | 'check' | 'calendar' | 'clock' = 'shield';
  let sections: { h: string; t: string }[] = [];
  let tiers = false;

  if (current?.kind === 'signal') {
    title = signalLabel(current.signal);
    icon = SIGNAL_ICON[current.signal];
    sections = [
      { h: tr('What this means'), t: MEANS[current.signal](name) },
      { h: tr('What this does not mean'), t: tr(NOT[current.signal]) },
    ];
  } else if (current?.kind === 'unavailable') {
    kicker = tr('VERIFICATION STATUS');
    title = tr('Status unavailable');
    icon = 'clock';
    const n = name ?? tr('this person');
    sections = [
      { h: tr('What’s happening'), t: tr('We couldn’t confirm {n}’s verification status right now, so we’re not showing any signals rather than an out-of-date one.', { n }) },
      { h: tr('What it doesn’t mean'), t: tr('It doesn’t mean {n} is unverified or untrustworthy.', { n }) },
    ];
  } else if (current?.kind === 'about') {
    kicker = 'TRUST';
    title = tr('About trust signals');
    sections = [{ h: tr('Why do I see these signals?'), t: tr('They give context about information that has been verified, or that you and another person share — like a Plan or an event.') }];
    tiers = true;
  }

  return (
    <Sheet visible={!!current} onClose={close} label={title}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 12 }}>
        <IconTile name={icon} size={44} />
        <View style={{ flex: 1 }}>
          <T variant="kicker">{kicker}</T>
          <T variant="heading">{title}</T>
        </View>
      </View>
      {sections.map((s) => (
        <View key={s.h} style={{ marginBottom: 12 }}>
          <T variant="bodyStrong">{s.h}</T>
          <T variant="body" style={{ marginTop: 3 }}>{s.t}</T>
        </View>
      ))}
      {tiers ? (
        <View style={{ gap: 10, marginBottom: 12 }}>
          {[
            [tr('STRONG FACTUAL'), [tr('Identity verified'), tr('Organizer verified'), tr('Official event')]],
            ['CONTACT', [tr('Phone verified'), tr('Email verified')]],
          ].map(([label, items]) => (
            <View key={label as string}>
              <T variant="kicker" style={{ color: colors.inkSoft }}>{label as string}</T>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 6 }}>
                {(items as string[]).map((i) => <Pill key={i} label={i} />)}
              </View>
            </View>
          ))}
          <T variant="small">{tr('Shared context — a shared Plan, event, destination or mutual connection — is shown separately and isn’t verification.')}</T>
          <View style={{ backgroundColor: colors.brandPale, padding: 12, borderRadius: 12 }}>
            <T variant="small" style={{ color: colors.brandDark }}>
              <T variant="small" style={{ fontFamily: 'DMSans_700Bold', color: colors.brandDark }}>{tr('Important.')}{' '}</T>
              {tr('Plans never shows trust or safety scores, ratings or rankings. Not being verified is common and shown neutrally.')}
            </T>
          </View>
        </View>
      ) : null}
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Button label={tr('Got it')} onPress={close} style={{ flex: 1 }} />
        {current?.kind !== 'about' ? <Button label={tr('About trust signals')} kind="secondary" onPress={() => setAbout(true)} style={{ flex: 1 }} /> : null}
      </View>
      {current?.kind === 'signal' && (current.signal === 'IDENTITY' || current.signal === 'ORGANIZER') ? (
        <Button label={tr('Report a fake identity')} kind="text" icon="flag" onPress={() => { close(); router.push('/safety'); }} style={{ marginTop: 6 }} />
      ) : null}
    </Sheet>
  );
}

export function SignalIcon({ signal }: { signal: Signal }) {
  useLanguage();
  return <Icon name={SIGNAL_ICON[signal]} size={12} color={colors.brand} />;
}
