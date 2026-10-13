// Design tokens taken from the "Social Discovery App Design" prototype.
export const colors = {
  ink: '#182321',
  inkSoft: '#53635f',
  paper: '#f7f8f4',
  /** Frosted glass fill for cards and groups (see glass.fill). Use surfaceSolid where something must be opaque. */
  surface: 'rgba(255,255,255,0.72)',
  surfaceSolid: '#ffffff',
  /** Soft edge between glass pieces. */
  line: 'rgba(24,35,33,0.1)',
  /** Outline for inputs and checkboxes: 3.4:1 on white, meeting WCAG 1.4.11 for controls. */
  inputBorder: '#74847e',
  brand: '#126b55',
  brandDark: '#0c4f40',
  brandPale: '#e0f1e9',
  lime: '#dff060',
  violet: '#7156d9',
  danger: '#b94343',
  /** Error text that sits straight on the backdrop (under inputs): darker than danger for 4.5:1. */
  dangerText: '#9a3030',
  badge: '#c94e4e',
  /** Switch off-state: 3:1 against the backdrop so "off" is visible, not just faint. */
  track: '#8b9993',
  divider: 'rgba(24,35,33,0.07)',
  frame: '#eceee9',
  dangerPale: '#f8e5e5',
  warning: '#9b5d2d',
  warningPale: '#f7ecdf',
  muted: '#edf0ec',
};

export const avatarTones = {
  mint: { bg: '#bce0d0', fg: '#315849' },
  violet: { bg: '#d7cff0', fg: '#49377a' },
  coral: { bg: '#efc5b4', fg: '#714433' },
  blue: { bg: '#bfdae6', fg: '#28556b' },
} as const;

/** Status pills used across verification, reports and settings. */
export const pills = {
  ok: { bg: '#e0f1e9', fg: '#126b55' },
  neutral: { bg: '#eef1ee', fg: '#3d4a47' },
  blue: { bg: '#e0edf2', fg: '#2b5c74' },
  warn: { bg: '#fff0cb', fg: '#795f27' },
  bad: { bg: '#faeaea', fg: '#b94343' },
  ink: { bg: '#182321', fg: '#ffffff' },
  lime: { bg: '#dff060', fg: '#182321' },
} as const;
export type PillTone = keyof typeof pills;

export type AvatarTone = keyof typeof avatarTones;

export const fonts = {
  display: 'Manrope_800ExtraBold',
  displayBold: 'Manrope_700Bold',
  body: 'DMSans_400Regular',
  bodyMedium: 'DMSans_500Medium',
  bodySemi: 'DMSans_600SemiBold',
  bodyBold: 'DMSans_700Bold',
};

export const radius = { sm: 10, md: 14, lg: 20, xl: 24, pill: 999 };

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 28 };

export const shadow = {
  shadowColor: '#1c3029',
  shadowOpacity: 0.07,
  shadowRadius: 18,
  shadowOffset: { width: 0, height: 6 },
  elevation: 2,
};

/**
 * Glass surfaces. Fills stay mostly opaque on purpose: text sits on them, and every text colour keeps
 * WCAG AA contrast (≥4.5:1) against the fill composited over the brightest part of the backdrop.
 * See scripts/contrast.mjs.
 */
export const glass = {
  fill: 'rgba(255,255,255,0.72)',
  fillStrong: 'rgba(255,255,255,0.88)',
  fillSoft: 'rgba(255,255,255,0.5)',
  border: 'rgba(255,255,255,0.9)',
  hairline: 'rgba(24,35,33,0.08)',
  pressed: 'rgba(224,241,233,0.9)',
  /** Light catching the top edge of the glass. */
  highlight: 'rgba(255,255,255,0.95)',
  shadow: {
    shadowColor: '#0c4f40',
    shadowOpacity: 0.1,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 10 },
    elevation: 3,
  },
} as const;

/**
 * The aurora behind every screen: morning light over a park, where Plans happen.
 * Brand mint at the top, a lime sun, a soft violet dusk at the bottom. Kept pale so glass stays readable.
 */
export const aurora = {
  base: ['#f4f8f2', '#eef6f1', '#f3f1fa'] as const,
  mint: 'rgba(129,206,170,0.32)',
  lime: 'rgba(223,240,96,0.35)',
  violet: 'rgba(170,152,235,0.2)',
};

/** Primary action fill: a little depth so the main button reads as the next step. */
export const brandGradient = ['#178066', '#0e5c49'] as const;

/** Placeholder text: darker than the old #8a9893 so it passes 4.5:1 on inputs. */
export const placeholder = '#5c6b65';

export const motion = { fast: 140, base: 220, slow: 420 };

