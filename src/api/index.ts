import { http, query } from './client';
import type {
  AppNotification, AuthResponse, BlockedUser, Connection, ConnectionRequest, ConversationDetail,
  ConversationSummary, DiscoverResponse, Me, Message, MyPlans, NotificationPrefs, OrganizerProfile,
  OrganizerType, OtpRequestResponse, PersonCard, PlanDetail, PlanRequest, PlanSummary, PlanUpdateRequest,
  PrivacySettings, PublicProfile, Report, ReportTarget, SecurityEvent, Session, VerificationState,
} from './types';

export * from './types';
export { ApiError, API_URL } from './client';

export type Channel = 'PHONE' | 'EMAIL';

export const authApi = {
  requestOtp: (channel: Channel, destination: string) =>
    http.post<OtpRequestResponse>('/api/auth/otp/request', { channel, destination }),
  verifyOtp: (channel: Channel, destination: string, code: string) =>
    http.post<AuthResponse>('/api/auth/otp/verify', { channel, destination, code }),
  logout: (refreshToken: string) => http.post<void>('/api/auth/logout', { refreshToken }),
};

export interface ProfileUpdate {
  displayName: string;
  birthYear?: number | null;
  area: string;
  city?: string;
  bio?: string;
  photoUrl?: string | null;
  interests: string[];
  languages: string[];
  intents: string[];
}

export const meApi = {
  get: () => http.get<Me>('/api/me'),
  update: (body: ProfileUpdate) => http.put<Me>('/api/me', body),
  updateName: (displayName: string) => http.put<Me>('/api/me/name', { displayName }),
  updatePrivacy: (body: Partial<PrivacySettings>) => http.put<Me>('/api/me/privacy', body),
  completeOnboarding: () => http.post<Me>('/api/me/onboarding-complete'),
  changePassword: (currentPassword: string | null, newPassword: string) =>
    http.put<void>('/api/me/password', { currentPassword, newPassword }),
  startContactChange: (channel: Channel, value: string) =>
    http.post<OtpRequestResponse>('/api/me/contact/start', { channel, value }),
  confirmContactChange: (channel: Channel, value: string, code: string) =>
    http.post<Me>('/api/me/contact/confirm', { channel, value, code }),
  sessions: () => http.get<Session[]>('/api/me/sessions'),
  signOutSession: (id: number) => http.del<void>(`/api/me/sessions/${id}`),
  signOutOthers: () => http.post<void>('/api/me/sessions/sign-out-others'),
  securityEvents: () => http.get<SecurityEvent[]>('/api/me/security-events'),
  deactivate: () => http.post<Me>('/api/me/deactivate'),
  reactivate: () => http.post<Me>('/api/me/reactivate'),
  requestDeletion: () => http.post<void>('/api/me/deletion'),
  cancelDeletion: () => http.del<Me>('/api/me/deletion'),
  registerPushToken: (token: string, platform: string) => http.post<void>('/api/me/push-tokens', { token, platform }),
};

export const discoverApi = {
  home: (filter: 'all' | 'official' = 'all') => http.get<DiscoverResponse>(`/api/discover${query({ filter })}`),
  search: (q: string) => http.get<{ plans: PlanSummary[]; people: PersonCard[] }>(`/api/search${query({ q })}`),
};

export const plansApi = {
  mine: () => http.get<MyPlans>('/api/plans/mine'),
  get: (id: number) => http.get<PlanDetail>(`/api/plans/${id}`),
  create: (body: PlanRequest) => http.post<PlanDetail>('/api/plans', body),
  updateDraft: (id: number, body: PlanRequest) => http.put<PlanDetail>(`/api/plans/${id}`, body),
  updateDetails: (id: number, body: PlanUpdateRequest) => http.put<PlanDetail>(`/api/plans/${id}/details`, body),
  join: (id: number) => http.post<PlanDetail>(`/api/plans/${id}/join`),
  leave: (id: number) => http.post<PlanDetail>(`/api/plans/${id}/leave`),
  cancel: (id: number, reason: string) => http.post<PlanDetail>(`/api/plans/${id}/cancel`, { reason }),
  complete: (id: number) => http.post<PlanDetail>(`/api/plans/${id}/complete`),
  remove: (id: number) => http.del<void>(`/api/plans/${id}`),
  removeParticipant: (id: number, userId: number) => http.del<PlanDetail>(`/api/plans/${id}/participants/${userId}`),
  announce: (id: number, title: string, body: string) => http.post<void>(`/api/plans/${id}/announcements`, { title, body }),
};

export const usersApi = {
  get: (id: number) => http.get<PublicProfile>(`/api/users/${id}`),
};

export const connectionsApi = {
  list: () => http.get<Connection[]>('/api/connections'),
  request: (id: number) => http.get<ConnectionRequest>(`/api/connections/requests/${id}`),
  incoming: () => http.get<ConnectionRequest[]>('/api/connections/requests'),
  send: (userId: number, planId?: number | null, note?: string) =>
    http.post<ConnectionRequest>('/api/connections/requests', { userId, planId, note }),
  accept: (id: number) => http.post<ConnectionRequest>(`/api/connections/requests/${id}/accept`),
  decline: (id: number) => http.post<ConnectionRequest>(`/api/connections/requests/${id}/decline`),
  cancel: (id: number) => http.post<ConnectionRequest>(`/api/connections/requests/${id}/cancel`),
  remove: (userId: number) => http.del<void>(`/api/connections/${userId}`),
};

export const chatApi = {
  list: () => http.get<ConversationSummary[]>('/api/conversations'),
  get: (id: number) => http.get<ConversationDetail>(`/api/conversations/${id}`),
  openDirect: (userId: number) => http.post<ConversationSummary>('/api/conversations/direct', { userId }),
  messages: (id: number, before?: number) => http.get<Message[]>(`/api/conversations/${id}/messages${query({ before })}`),
  send: (id: number, text: string, clientId: string) =>
    http.post<Message>(`/api/conversations/${id}/messages`, { text, clientId }),
  markRead: (id: number) => http.post<void>(`/api/conversations/${id}/read`),
  mute: (id: number, muted: boolean) => http.post<void>(`/api/conversations/${id}/mute`, { muted }),
};

export const notificationsApi = {
  list: () => http.get<AppNotification[]>('/api/notifications'),
  markRead: (id: number, read = true) => http.post<void>(`/api/notifications/${id}/read`, { read }),
  markAllRead: () => http.post<void>('/api/notifications/read-all'),
  prefs: () => http.get<NotificationPrefs>('/api/notifications/preferences'),
  updatePrefs: (p: Partial<NotificationPrefs>) => http.put<NotificationPrefs>('/api/notifications/preferences', p),
};

export const safetyApi = {
  report: (body: { targetType: ReportTarget; targetId?: number | null; reason: string; details?: string; blockUserId?: number | null }) =>
    http.post<Report>('/api/reports', body),
  reports: () => http.get<Report[]>('/api/reports'),
  reportDetail: (id: number) => http.get<Report>(`/api/reports/${id}`),
  block: (userId: number) => http.post<void>('/api/blocks', { userId }),
  unblock: (userId: number) => http.del<void>(`/api/blocks/${userId}`),
  blocked: () => http.get<BlockedUser[]>('/api/blocks'),
};

export const verificationApi = {
  state: () => http.get<VerificationState>('/api/verification'),
  startIdentity: () => http.post<{ sessionId: string; providerUrl?: string | null }>('/api/verification/identity/sessions'),
  submitIdentity: (sessionId: string) => http.post<VerificationState>(`/api/verification/identity/sessions/${sessionId}/submit`),
  sendPhoneCode: () => http.post<OtpRequestResponse>('/api/verification/phone/send'),
  verifyPhone: (code: string) => http.post<VerificationState>('/api/verification/phone/verify', { code }),
  sendEmailLink: (email?: string) => http.post<VerificationState>('/api/verification/email/send', { email }),
};

export interface OrganizerSetup {
  type: OrganizerType;
  name: string;
  about: string;
  area: string;
  website?: string;
  contactEmail?: string;
}

export const organizersApi = {
  get: (id: number) => http.get<OrganizerProfile>(`/api/organizers/${id}`),
  apply: (body: OrganizerSetup) => http.post<OrganizerProfile>('/api/organizers', body),
};

/** Off until the person opts in (privacy choices). The server also drops events without consent. */
let analyticsAllowed = false;
export function setAnalyticsAllowed(v: boolean) {
  analyticsAllowed = v;
}

export const analyticsApi = {
  track: (name: string, properties: Record<string, string | number | boolean> = {}) =>
    analyticsAllowed ? http.post<void>('/api/analytics', { name, properties }).catch(() => undefined) : Promise.resolve(undefined),
};

export interface ConsentRow { kind: string; granted: boolean; version: string; source: string; at: string }
export interface Consents { analytics: boolean; offers: boolean; marketingEmails: boolean; decided: boolean; policyVersion: string; history: ConsentRow[] }
export interface ContentPage { id: number; slug: string; title: string; body: string; published: boolean; updatedAt: string }

export const privacyApi = {
  consents: () => http.get<Consents>('/api/me/consents'),
  saveConsents: (c: { analytics: boolean; offers: boolean; marketingEmails: boolean; source?: 'PROMPT' | 'SETTINGS' }) =>
    http.put<Consents>('/api/me/consents', c),
  recordSignup: () => http.post<void>('/api/me/consents/signup'),
  exportData: () => http.get<Record<string, unknown>>('/api/me/export'),
  deleteUnderage: () => http.post<void>('/api/me/underage'),
};

export const contentApi = {
  page: (slug: string) => http.get<ContentPage>(`/api/content/pages/${encodeURIComponent(slug)}`),
};
