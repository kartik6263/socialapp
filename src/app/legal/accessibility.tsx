import { router } from 'expo-router';
import { Button, Group, Header, Row, Screen, SectionTitle, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { openReport } from '@/lib/report';
import { tr, useLanguage } from '@/i18n';

/** Accessibility statement: what we support, and how to tell us when something doesn't work. */
export default function Accessibility() {
  useLanguage();
  const { user } = useAuth();
  return (
    <Screen>
      <Header kicker={tr('ABOUT')} title={tr('Accessibility')} />
      <T variant="body">{tr('We aim for WCAG 2.2 level AA. Here’s what Plans supports today.')}</T>

      <SectionTitle title={tr('Supported')} />
      <Group>
        <Row first icon="volume-2" label={tr('Screen readers')} sub={tr('TalkBack and VoiceOver: every button, switch and image has a label; headings are marked.')} />
        <Row icon="type" label={tr('Text size')} sub={tr('Follows your phone’s font size setting.')} />
        <Row icon="pause-circle" label={tr('Reduce motion')} sub={tr('Animations turn off when your phone’s reduce-motion setting is on.')} />
        <Row icon="droplet" label={tr('Colour contrast')} sub={tr('Text meets 4.5:1 contrast, checked against the glass backgrounds. State is never shown by colour alone.')} />
        <Row icon="command" label={tr('Keyboard & switch access')} sub={tr('Use Tab or a switch to move between controls; the focused control shows a blue outline.')} />
        <Row icon="maximize" label={tr('Touch targets')} sub={tr('Buttons are at least 44 points tall.')} />
      </Group>

      <SectionTitle title={tr('Known limits')} />
      <Group>
        <Row first icon="globe" label={tr('Translations')} sub={tr('Policy pages are in English only for now.')} />
      </Group>

      {user?.onboarded ? (
        <Button
          label={tr('Report an accessibility problem')}
          kind="secondary"
          icon="flag"
          style={{ marginTop: 18 }}
          onPress={() => openReport({ targetType: 'PROBLEM', title: tr('Accessibility problem') })}
        />
      ) : (
        <Button label={tr('Contact details')} kind="secondary" icon="mail" style={{ marginTop: 18 }} onPress={() => router.push('/legal/business')} />
      )}
    </Screen>
  );
}
