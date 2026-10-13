import Constants from 'expo-constants';

/**
 * Business and grievance details shown in the app (About, Help, policies).
 * India’s IT Rules 2021 and the DPDP Act require a reachable Grievance Officer; app stores require a support contact.
 *
 * FILL THESE IN BEFORE LAUNCH. Bracketed values are placeholders, and the app labels them as "to be added".
 * Keep them in step with the policy pages in the Admin Console (Content → Pages & policies).
 */
export const business = {
  legalName: '[Company legal name]',
  brand: 'Plans',
  registeredAddress: '[Registered office address, City, State, PIN]',
  cin: '[CIN / registration number]',
  gstin: '[GSTIN, if registered]',
  supportEmail: '[support@yourdomain]',
  privacyEmail: '[privacy@yourdomain]',
  grievanceOfficer: { name: '[Grievance Officer name]', email: '[grievance@yourdomain]' },
  /** Shown as the expected first-response time. Only state what the team actually commits to. */
  responseTime: '[e.g. within 2 working days]',
  website: '[https://yourdomain]',
};

export const appVersion = Constants.expoConfig?.version ?? '1.0.0';

export const isPlaceholder = (v: string) => /^\[.*\]$/.test(v.trim());

/** A usable email address, or null while it's still a placeholder (so we never open a broken mailto:). */
export const emailOrNull = (v: string) => (isPlaceholder(v) || !v.includes('@') ? null : v);
