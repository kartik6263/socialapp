import { INTENTS, SIGNAL_ORDER, type Intent, type Signal } from '@/api/types';
import { getLang, translate as t, type Lang } from '@/i18n';

const DAYS: Record<Lang, string[]> = {
  en: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
  hi: ['रवि', 'सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि'],
  kn: ['ಭಾನು', 'ಸೋಮ', 'ಮಂಗಳ', 'ಬುಧ', 'ಗುರು', 'ಶುಕ್ರ', 'ಶನಿ'],
};
const MONTHS: Record<Lang, string[]> = {
  en: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  hi: ['जन', 'फ़र', 'मार्च', 'अप्रैल', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्टू', 'नव', 'दिस'],
  kn: ['ಜನ', 'ಫೆಬ್ರ', 'ಮಾರ್ಚ್', 'ಏಪ್ರಿ', 'ಮೇ', 'ಜೂನ್', 'ಜುಲೈ', 'ಆಗ', 'ಸೆಪ್ಟೆಂ', 'ಅಕ್ಟೋ', 'ನವೆಂ', 'ಡಿಸೆಂ'],
};
const day = (d: Date) => DAYS[getLang()][d.getDay()];
const month = (d: Date) => MONTHS[getLang()][d.getMonth()];

export function clock(d: Date) {
  const h = d.getHours();
  const m = d.getMinutes();
  const suffix = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 || 12;
  return `${h12}:${String(m).padStart(2, '0')} ${suffix}`;
}

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** "Today · 5:00 PM", "Sat, 21 Sep · 7:00 AM", or "20–23 Sep" for multi-day plans. */
export function planDate(startIso?: string | null, endIso?: string | null) {
  if (!startIso) return t('Date not set');
  const start = new Date(startIso);
  if (endIso) {
    const end = new Date(endIso);
    if (!sameDay(start, end)) {
      if (start.getMonth() === end.getMonth()) return `${start.getDate()}–${end.getDate()} ${month(end)}`;
      return `${start.getDate()} ${month(start)} – ${end.getDate()} ${month(end)}`;
    }
  }
  if (sameDay(start, new Date())) return `${t('Today')} · ${clock(start)}`;
  if (sameDay(start, new Date(Date.now() + 86400000))) return `${t('Tomorrow')} · ${clock(start)}`;
  return `${day(start)}, ${start.getDate()} ${month(start)} · ${clock(start)}`;
}

export function shortDate(iso: string) {
  const d = new Date(iso);
  return `${d.getDate()} ${month(d)}`;
}

/** Notification / report timestamps: "Just now", "8 min ago", "3 hr ago", "6:40 PM", "Mon", "14 Sep". */
export function relativeTime(iso: string) {
  const d = new Date(iso);
  const diff = (Date.now() - d.getTime()) / 1000;
  if (diff < 60) return t('Just now');
  if (diff < 3600) return t('{n} min ago', { n: Math.floor(diff / 60) });
  if (diff < 6 * 3600) return t('{n} hr ago', { n: Math.floor(diff / 3600) });
  if (diff < 2 * 86400) return clock(d);
  if (diff < 7 * 86400) return day(d);
  return shortDate(iso);
}

export type Section = 'Today' | 'Yesterday' | 'This week' | 'Earlier';
export function sectionFor(iso: string): Section {
  const d = new Date(iso);
  if (sameDay(d, new Date())) return 'Today';
  if (sameDay(d, new Date(Date.now() - 86400000))) return 'Yesterday';
  if (Date.now() - d.getTime() < 7 * 86400000) return 'This week';
  return 'Earlier';
}

export function dayLabel(iso: string) {
  const d = new Date(iso);
  if (sameDay(d, new Date())) return t('Today');
  if (sameDay(d, new Date(Date.now() - 86400000))) return t('Yesterday');
  return `${day(d)}, ${d.getDate()} ${month(d)}`;
}

export function monthYear(iso: string) {
  const d = new Date(iso);
  return `${month(d)} ${d.getFullYear()}`;
}

export function messageTime(iso: string) {
  return clock(new Date(iso));
}

export function initials(name: string) {
  return (
    name
      .replace(/[’'.,]/g, '')
      .split(/\s+/)
      .filter(Boolean)
      .map((p) => p[0])
      .join('')
      .slice(0, 2)
      .toUpperCase() || '?'
  );
}

export function firstName(name: string) {
  return name.split(/\s+/)[0] ?? name;
}

const TONES = ['mint', 'violet', 'coral', 'blue'] as const;
export function toneFor(id: number) {
  return TONES[Math.abs(id) % TONES.length];
}

export const intentLabel = (i: Intent) => t(INTENTS.find((x) => x.value === i)?.label ?? i);

/** "OPEN TO ACTIVITY PARTNERS" kicker shown above names. */
export function intentKicker(intents: Intent[]) {
  if (!intents.length) return '';
  return t('Open to {intents}', { intents: intents.slice(0, 2).map(intentLabel).join(' · ') }).toUpperCase();
}

const SIGNAL_LABELS: Record<Signal, string> = {
  IDENTITY: 'Identity verified',
  ORGANIZER: 'Organizer verified',
  OFFICIAL: 'Official event',
  PHONE: 'Phone verified',
  EMAIL: 'Email verified',
};

export const signalLabel = (s: Signal) => t(SIGNAL_LABELS[s]);


export function sortSignals(s: Signal[]) {
  return [...s].sort((a, b) => SIGNAL_ORDER.indexOf(a) - SIGNAL_ORDER.indexOf(b));
}

/** The single strongest signal, for compact rows ("Phone verified"). */
export function topSignal(s: Signal[]) {
  return s.length ? signalLabel(sortSignals(s)[0]) : null;
}
