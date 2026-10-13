import type { PrivacySettings } from '@/api/types';
import { tr } from '@/i18n';

export type ChoiceKey = 'profileVisibility' | 'areaLevel' | 'defaultPlanVisibility' | 'planLocation' | 'connectionRequests' | 'messages' | 'language';

interface Choice {
  kicker: string;
  title: string;
  intro: string;
  note?: string;
  opts: { value: string; label: string; sub?: string; short: string }[];
}

export const CHOICES: Record<ChoiceKey, Choice> = {
  profileVisibility: {
    kicker: 'PRIVACY', title: 'Profile visibility',
    intro: 'Your profile can show your public profile information, Plans and relevant shared context according to your privacy settings.',
    opts: [
      { value: 'EVERYONE', label: 'Visible to people using Plans', sub: 'People discovering nearby Plans can open your profile.', short: 'Everyone on Plans' },
      { value: 'SHARED_CONTEXT', label: 'Only people with shared context', sub: 'Only people in the same Plan, event or destination can open your profile.', short: 'Shared context only' },
    ],
  },
  areaLevel: {
    kicker: 'LOCATION', title: 'Area detail', intro: 'How broad your approximate area is when shown.',
    opts: [
      { value: 'NEIGHBOURHOOD', label: 'Neighbourhood', sub: 'Shown as “Indiranagar area”.', short: 'Neighbourhood' },
      { value: 'CITY', label: 'City only', sub: 'Shown as “Bengaluru”.', short: 'City only' },
    ],
  },
  defaultPlanVisibility: {
    kicker: 'PRIVACY', title: 'Default Plan visibility', intro: 'Used for new Plans you create. You can change it on each Plan.',
    opts: [
      { value: 'DISCOVERABLE', label: 'Discoverable', sub: 'Discoverable Plans can appear in relevant discovery results.', short: 'Discoverable' },
      { value: 'SHARED_CONTEXT', label: 'Shared-context only', sub: 'Only people with a shared event, destination or connection can find it.', short: 'Shared-context only' },
      { value: 'PRIVATE', label: 'Private', sub: 'Private Plans are not publicly discoverable. Only people with the link can join.', short: 'Private' },
    ],
  },
  planLocation: {
    kicker: 'LOCATION', title: 'Plan location', intro: 'What people see about where your Plans happen. Meeting points are always public places.',
    note: 'Destinations and official event venues are always shown, because they’re already public.',
    opts: [
      { value: 'APPROXIMATE', label: 'Approximate area until people join', sub: 'Participants see the exact public meeting point after joining.', short: 'Approximate until joined' },
      { value: 'PUBLIC_VENUE', label: 'Public venue for everyone', sub: 'Only for public places like cafés, parks and event venues.', short: 'Public venue' },
    ],
  },
  connectionRequests: {
    kicker: 'CONTACT', title: 'Who can send me connection requests?', intro: 'Requests always show the shared Plan or context they came from.',
    opts: [
      { value: 'MY_PLANS', label: 'People from my Plans', sub: 'Only people who joined the same Plan as you.', short: 'People from my Plans' },
      { value: 'SHARED_CONTEXT', label: 'People with shared context', sub: 'Same Plan, event, or destination and dates.', short: 'Shared context' },
      { value: 'ANYONE', label: 'Anyone who can discover me', sub: 'Anyone who can see your profile, based on your visibility setting.', short: 'Anyone who can discover me' },
      { value: 'NOBODY', label: 'Nobody', sub: 'You can still send requests yourself.', short: 'Nobody' },
    ],
  },
  messages: {
    kicker: 'CONTACT', title: 'Who can message me?', intro: 'Blocked people can never message you, whatever you choose here.',
    opts: [
      { value: 'CONNECTED', label: 'Connected people only', sub: 'People you’ve accepted a connection with.', short: 'Connected people' },
      { value: 'CONNECTED_AND_PLANS', label: 'Connected people and people from my Plans', sub: 'Includes people in the same Plan, before connecting.', short: 'Connected + my Plans' },
      { value: 'NOBODY', label: 'Nobody', sub: 'Existing conversations become read-only. Plan Groups still work.', short: 'Nobody' },
    ],
  },
  language: {
    kicker: 'PREFERENCES', title: 'Language', intro: 'English is the default. Hindi is fully supported; Kannada is a secondary language and may show some English.',
    opts: [
      { value: 'en', label: 'English', sub: 'Default', short: 'English' },
      { value: 'hi', label: 'हिन्दी', sub: 'Hindi', short: 'हिन्दी' },
      { value: 'kn', label: 'ಕನ್ನಡ', sub: 'Kannada · secondary language', short: 'ಕನ್ನಡ' },
    ],
  },
};

/** Translated short value for settings rows (language names stay in their own script). */
export const shortChoice = (key: ChoiceKey, p: PrivacySettings) => {
  const short = CHOICES[key].opts.find((o) => o.value === p[key])?.short ?? '';
  return key === 'language' ? short : tr(short);
};
