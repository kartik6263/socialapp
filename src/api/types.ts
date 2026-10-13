// Mirrors the DTOs exposed by the Spring Boot backend (backend/src/main/java/com/plans/**/dto).

// ---------- Trust ----------

/** Factual trust signals. Never scores, ratings or rankings. */
export type Signal = 'IDENTITY' | 'ORGANIZER' | 'OFFICIAL' | 'PHONE' | 'EMAIL';
export const SIGNAL_ORDER: Signal[] = ['IDENTITY', 'ORGANIZER', 'OFFICIAL', 'PHONE', 'EMAIL'];

export type VerificationStatus =
  | 'NOT_STARTED' | 'PENDING' | 'IN_PROGRESS' | 'VERIFIED' | 'NEEDS_ATTENTION'
  | 'EXPIRED' | 'FAILED' | 'UNAVAILABLE';

export type OrganizerStatus =
  | 'NONE' | 'INCOMPLETE' | 'SUBMITTED' | 'IN_REVIEW' | 'MORE_INFO' | 'VERIFIED' | 'FAILED' | 'EXPIRED' | 'UNAVAILABLE';

export interface VerificationState {
  identity: { status: VerificationStatus; expiresAt?: string | null };
  phone: { status: VerificationStatus; masked?: string | null };
  email: { status: VerificationStatus; masked?: string | null };
  organizer: { status: OrganizerStatus; organizerId?: number | null; name?: string | null };
}

// ---------- People ----------

export type Intent =
  | 'FRIENDS' | 'TRAVEL_COMPANIONS' | 'ACTIVITY_PARTNERS' | 'NETWORKING' | 'DATING' | 'OPEN_TO_MEETING';

export const INTENTS: { value: Intent; label: string }[] = [
  { value: 'FRIENDS', label: 'Friends' },
  { value: 'ACTIVITY_PARTNERS', label: 'Activity partners' },
  { value: 'TRAVEL_COMPANIONS', label: 'Travel companions' },
  { value: 'NETWORKING', label: 'Networking' },
  { value: 'OPEN_TO_MEETING', label: 'Open to meeting people' },
  { value: 'DATING', label: 'Dating' },
];

export const INTERESTS = [
  'Travel', 'Trekking', 'Live music', 'Photography', 'Startups', 'Technology', 'Hackathons', 'Sports',
  'Football', 'Cycling', 'Fitness', 'College events', 'Networking', 'Movies', 'Cafés', 'Design', 'Gaming', 'Food',
];

export interface UserSummary {
  id: number;
  displayName: string;
  photoUrl?: string | null;
  area?: string | null;
  signals: Signal[];
  signalsUnavailable?: boolean;
}

export type AccountStatus = 'ACTIVE' | 'RESTRICTED' | 'DEACTIVATED' | 'DELETION_REQUESTED' | 'SUSPENDED';

export type ProfileVisibility = 'EVERYONE' | 'SHARED_CONTEXT';
export type AreaLevel = 'NEIGHBOURHOOD' | 'CITY';
export type PlanVisibility = 'DISCOVERABLE' | 'SHARED_CONTEXT' | 'PRIVATE';
export type PlanLocationDefault = 'APPROXIMATE' | 'PUBLIC_VENUE';
export type RequestPolicy = 'MY_PLANS' | 'SHARED_CONTEXT' | 'ANYONE' | 'NOBODY';
export type MessagePolicy = 'CONNECTED' | 'CONNECTED_AND_PLANS' | 'NOBODY';

export interface PrivacySettings {
  profileVisibility: ProfileVisibility;
  areaLevel: AreaLevel;
  defaultPlanVisibility: PlanVisibility;
  planLocation: PlanLocationDefault;
  connectionRequests: RequestPolicy;
  messages: MessagePolicy;
  language: 'en' | 'hi' | 'kn';
  showAge: boolean;
  showArea: boolean;
  showIntent: boolean;
  showInterests: boolean;
  showPlans: boolean;
  discoverPeople: boolean;
  discoverParticipants: boolean;
  discoverDestination: boolean;
  discoverSearch: boolean;
}

export interface Me extends UserSummary {
  ageRange?: string | null;
  bio?: string | null;
  city?: string | null;
  interests: string[];
  languages: string[];
  intents: Intent[];
  maskedPhone?: string | null;
  maskedEmail?: string | null;
  onboarded: boolean;
  accountStatus: AccountStatus;
  role: 'USER' | 'ADMIN';
  privacy: PrivacySettings;
  completeness: { percent: number; done: number; total: number; hint?: string | null };
  organizer?: OrganizerSummary | null;
  hasPassword: boolean;
  passwordChangedAt?: string | null;
  memberSince: string;
  unreadNotifications: number;
  unreadConversations: number;
}

export type ConnectionStatus = 'NONE' | 'PENDING_OUTGOING' | 'PENDING_INCOMING' | 'ACCEPTED' | 'BLOCKED';
export type Availability = 'AVAILABLE' | 'RESTRICTED' | 'SUSPENDED' | 'DELETED';

export interface SharedPlanRef {
  id: number;
  title: string;
  when: string;
  label: string; // e.g. "YOU’RE BOTH JOINING"
}

export interface PublicProfile extends UserSummary {
  firstName: string;
  ageRange?: string | null;
  intents: Intent[];
  bio?: string | null;
  interests: string[];
  sharedInterests: string[];
  mutualConnections: string[];
  sharedPlan?: SharedPlanRef | null;
  connectionStatus: ConnectionStatus;
  connectionId?: number | null;
  blockedByMe: boolean;
  canMessage: boolean;
  canConnect: boolean;
  availability: Availability;
}

export interface PersonCard {
  user: UserSummary;
  bio?: string | null;
  context: string;
  sharedInterests: string[];
}

export interface OrganizerSummary {
  id: number;
  name: string;
  type: OrganizerType;
  status: OrganizerStatus;
  signals: Signal[];
  upcomingCount: number;
}

export type OrganizerType = 'INDIVIDUAL' | 'COMMUNITY' | 'ORGANIZATION' | 'OFFICIAL';

export interface OrganizerProfile extends OrganizerSummary {
  about?: string | null;
  area?: string | null;
  website?: string | null;
  since: string;
  mine: boolean;
  available: boolean;
  upcoming: PlanSummary[];
  past: PlanSummary[];
}

// ---------- Plans ----------

export type PlanStatus = 'DRAFT' | 'ACTIVE' | 'FULL' | 'UPDATED' | 'CANCELLED' | 'COMPLETED';
export type LocationMode = 'APPROXIMATE' | 'PUBLIC_VENUE' | 'OFFICIAL_VENUE';
export type RegistrationMode = 'APP' | 'EXTERNAL';

export const CATEGORIES = [
  'Travel', 'Trek', 'Photography', 'Concert', 'Event', 'Sports', 'Gaming', 'College', 'Hackathon',
  'Networking', 'Food', 'Movie', 'Other',
];

export interface Host {
  kind: 'USER' | 'ORGANIZER';
  id: number;
  name: string;
  photoUrl?: string | null;
  signals: Signal[];
  subtitle: string; // "Creator" / "Community organizer"
}

export interface PlanSummary {
  id: number;
  title: string;
  category: string;
  area: string;
  startAt?: string | null;
  endAt?: string | null;
  participantCount: number;
  participantLimit: number;
  status: PlanStatus;
  official: boolean;
  coverImageUrl?: string | null;
  host: Host;
  why?: string | null;
  joined: boolean;
  owner: boolean;
}

export interface FieldChange {
  field: string;
  label: string;
  from: string;
  to: string;
}

export interface PlanMember {
  user: UserSummary;
  role: 'CREATOR' | 'ORGANIZER' | 'PARTICIPANT';
  me: boolean;
}

export interface PlanDetail extends PlanSummary {
  description?: string | null;
  meetingPoint?: string | null;
  meetingPointHidden: boolean;
  locationMode: LocationMode;
  visibility: PlanVisibility;
  registrationMode: RegistrationMode;
  registrationUrl?: string | null;
  schedule: { time: string; what: string }[];
  bring?: string | null;
  eligibility?: string | null;
  instructions?: string | null;
  members: PlanMember[];
  groupConversationId?: number | null;
  latestChange?: { by: string; at: string; changes: FieldChange[] } | null;
  cancelReason?: string | null;
  /** Only returned to members; lets them share private Plans by link. */
  shareCode?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PlanRequest {
  asOrganizer: boolean;
  official: boolean;
  title: string;
  category: string;
  description?: string;
  area: string;
  startAt?: string | null;
  endAt?: string | null;
  locationMode: LocationMode;
  meetingPoint?: string;
  participantLimit: number;
  visibility: PlanVisibility;
  registrationMode: RegistrationMode;
  registrationUrl?: string;
  schedule: { time: string; what: string }[];
  bring?: string;
  eligibility?: string;
  instructions?: string;
  draft: boolean;
}

export interface PlanUpdateRequest {
  startAt?: string | null;
  meetingPoint?: string;
  participantLimit?: number;
  instructions?: string;
  notify: boolean;
}

export interface DiscoverResponse {
  plans: PlanSummary[];
  people: PersonCard[];
  organizerNearby?: OrganizerSummary | null;
  hiddenFromPeople: boolean;
}

export interface MyPlans {
  upcoming: PlanSummary[];
  hosting: PlanSummary[];
  drafts: PlanSummary[];
  past: PlanSummary[];
}

// ---------- Connections ----------

export interface ConnectionRequest {
  id: number;
  from: UserSummary;
  ageRange?: string | null;
  intents: Intent[];
  note?: string | null;
  sharedPlan?: SharedPlanRef | null;
  sharedInterests: string[];
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED';
  createdAt: string;
}

export interface Connection {
  id: number;
  user: UserSummary;
  context: string;
  connectedAt: string;
}

// ---------- Chat ----------

export interface Message {
  id: number;
  conversationId: number;
  sender?: UserSummary | null;
  mine: boolean;
  system: boolean;
  removed: boolean;
  text: string;
  createdAt: string;
}

export interface Announcement {
  title: string;
  body: string;
  by: string;
  at: string;
}

export interface ConversationSummary {
  id: number;
  type: 'DIRECT' | 'GROUP';
  title: string;
  context?: string | null;
  planId?: number | null;
  otherUser?: UserSummary | null;
  lastMessage?: Message | null;
  unread: number;
  muted: boolean;
}

export interface ConversationDetail extends ConversationSummary {
  planTitle?: string | null;
  planLine?: string | null;
  official: boolean;
  archived: boolean;
  archivedReason?: string | null;
  announcement?: Announcement | null;
  members: PlanMember[];
  canSend: boolean;
  blockedByMe: boolean;
  firstUnreadMessageId?: number | null;
}

// ---------- Notifications ----------

export type NotificationCategory = 'PLANS' | 'PEOPLE' | 'SAFETY';
export type DestinationKind = 'PLAN' | 'CHAT' | 'REQUEST' | 'GROUP' | 'PROFILE' | 'SECURITY' | 'REPORT' | 'VERIFY' | 'UNAVAILABLE';

export interface AppNotification {
  id: number;
  category: NotificationCategory;
  type: string;
  priority: 'HIGH' | 'NORMAL' | 'LOW';
  icon: string;
  actor?: UserSummary | null;
  title: string;
  body?: string | null;
  quote?: string | null;
  context?: string | null;
  diff: { label: string; from: string; to: string }[];
  cta: string;
  destination: { kind: DestinationKind; id?: number | null; mode?: string | null; reason?: string | null };
  read: boolean;
  createdAt: string;
}

export interface NotificationPrefs {
  push: boolean;
  directMessages: boolean;
  groupMessages: boolean;
  connectionRequests: boolean;
  acceptedRequests: boolean;
  planUpdates: boolean;
  planReminders: boolean;
  participantUpdates: boolean;
  cancellations: boolean;
  announcements: boolean;
  suggestions: boolean;
  remindDayBefore: boolean;
  remindHourBefore: boolean;
}

// ---------- Safety ----------

export type ReportTarget =
  | 'PROFILE' | 'PARTICIPANT' | 'MESSAGE' | 'CONVERSATION' | 'PLAN' | 'GROUP' | 'ORGANIZER' | 'EVENT' | 'PROBLEM';

export type ReportStatus = 'SUBMITTED' | 'UNDER_REVIEW' | 'ACTION_TAKEN' | 'NO_ACTION' | 'CLOSED';

export interface Report {
  id: number;
  targetType: ReportTarget;
  targetId?: number | null;
  targetLabel: string;
  personId?: number | null;
  personName?: string | null;
  reason: string;
  details?: string | null;
  status: ReportStatus;
  submittedAt: string;
  updatedAt: string;
  unseenUpdate: boolean;
}

export interface BlockedUser {
  user: UserSummary;
  context?: string | null;
  blockedAt: string;
}

// ---------- Account ----------

export interface Session {
  id: number;
  deviceName: string;
  platform: 'ANDROID' | 'IOS' | 'WEB';
  app: string;
  area?: string | null;
  lastActiveAt: string;
  current: boolean;
}

export interface SecurityEvent {
  id: number;
  title: string;
  deviceName?: string | null;
  area?: string | null;
  createdAt: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: Me;
  newUser: boolean;
}

export interface OtpRequestResponse {
  expiresInSeconds: number;
  resendInSeconds: number;
  devCode?: string | null;
}

export interface ApiErrorBody {
  status: number;
  code: string;
  message: string;
  fields?: Record<string, string>;
  existingId?: number | null;
}
