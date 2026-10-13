import { Group, Header, Note, Pill, Row, Screen, SectionTitle, T } from '@/components/ui';
import { tr, useLanguage } from '@/i18n';

/**
 * Third-party SDK audit, shown to users. Keep in step with package.json: every SDK that ships in the app is listed
 * with what it does, whether it sends anything off the device, and its licence.
 */
const SDKS: { name: string; purpose: string; data: string; licence: string; network: boolean }[] = [
  { name: 'Expo & React Native', purpose: 'The app framework', data: 'Nothing sent to Expo or Meta at runtime', licence: 'MIT', network: false },
  { name: 'Expo Notifications', purpose: 'Push notifications, only if you turn them on', data: 'A device push token, sent to our server and to Google (Firebase) or Apple to deliver notifications', licence: 'MIT', network: true },
  { name: 'Expo Secure Store', purpose: 'Keeps you signed in', data: 'Sign-in tokens, in your phone’s encrypted Keychain / Keystore', licence: 'MIT', network: false },
  { name: 'Expo Device & Constants', purpose: 'Names your session (e.g. “Pixel 7”)', data: 'Phone model and app version, sent to our server only', licence: 'MIT', network: false },
  { name: 'Expo File System & Sharing', purpose: '“Download your data”', data: 'Writes the export to your phone, then opens the share sheet', licence: 'MIT', network: false },
  { name: 'Expo Web Browser & Linking', purpose: 'Opens links you tap', data: 'Nothing, until you open a link', licence: 'MIT', network: false },
  { name: 'Expo Blur, Linear Gradient, React Native SVG', purpose: 'Visual design', data: 'Nothing', licence: 'MIT', network: false },
  { name: 'Expo Router, Screens, Safe Area', purpose: 'Navigation and layout', data: 'Nothing', licence: 'MIT', network: false },
  { name: 'Date/time picker (React Native Community)', purpose: 'Choosing Plan dates', data: 'Nothing', licence: 'MIT', network: false },
  { name: 'STOMP.js', purpose: 'Real-time chat', data: 'Your messages, to our server only', licence: 'Apache-2.0', network: true },
];

export default function Licenses() {
  useLanguage();
  return (
    <Screen>
      <Header kicker={tr('ABOUT')} title={tr('Third-party services')} />
      <T variant="body">{tr('Every SDK inside the app, what it’s for, and what (if anything) leaves your phone.')}</T>
      <Note icon="shield">{tr('No advertising, tracking or third-party analytics SDKs are included. Product analytics go only to our own server, and only if you agree.')}</Note>

      <SectionTitle title={tr('SDKs in the app')} />
      <Group>
        {SDKS.map((s, i) => (
          <Row
            key={s.name}
            first={i === 0}
            icon={s.network ? 'wifi' : 'smartphone'}
            label={s.name}
            sub={`${tr(s.purpose)} · ${tr(s.data)}`}
            right={<Pill label={s.licence} tone="neutral" />}
          />
        ))}
      </Group>

      <SectionTitle title={tr('Fonts')} />
      <Group>
        <Row first icon="type" label="Manrope" sub={tr('By Mikhail Sharanda. Bundled in the app.')} right={<Pill label="OFL 1.1" tone="neutral" />} />
        <Row icon="type" label="DM Sans" sub={tr('By Colophon Foundry for Google Fonts. Bundled in the app.')} right={<Pill label="OFL 1.1" tone="neutral" />} />
      </Group>
      <T variant="small" style={{ marginTop: 6 }}>{tr('SIL Open Font License 1.1 allows embedding in apps. Fonts load from the app itself, never from Google’s servers.')}</T>

      <SectionTitle title={tr('Icons & images')} />
      <Group>
        <Row first icon="feather" label="Feather icons" sub={tr('By Cole Bemis, via @expo/vector-icons.')} right={<Pill label="MIT" tone="neutral" />} />
        <Row icon="image" label={tr('Plan cover art')} sub={tr('Drawn by the app from shapes and colours. No stock photos are used.')} right={<Pill label={tr('Original')} tone="ok" />} />
        <Row icon="user" label={tr('Profile pictures')} sub={tr('Shown as initials. Photo upload isn’t available yet.')} />
      </Group>
    </Screen>
  );
}
