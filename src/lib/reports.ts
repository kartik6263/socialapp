import type { ReportStatus, ReportTarget } from '@/api/types';
import type { IconName } from '@/components/ui';
import type { PillTone } from '@/theme';

export const STATUS_LABEL: Record<ReportStatus, string> = {
  SUBMITTED: 'Submitted', UNDER_REVIEW: 'Under review', ACTION_TAKEN: 'Action taken', NO_ACTION: 'No action', CLOSED: 'Closed',
};

export const STATUS_TONE: Record<ReportStatus, PillTone> = {
  SUBMITTED: 'neutral', UNDER_REVIEW: 'blue', ACTION_TAKEN: 'ok', NO_ACTION: 'warn', CLOSED: 'neutral',
};

export const OUTCOME: Record<ReportStatus, string> = {
  SUBMITTED: 'Your report was received. We’ll review it soon.',
  UNDER_REVIEW: 'The report is being reviewed. We’ll update you here when it’s done.',
  ACTION_TAKEN: 'Appropriate action was taken under our community guidelines.',
  NO_ACTION: 'The review didn’t result in an action. You can still block this person at any time.',
  CLOSED: 'This report is closed.',
};

export const TYPE_LABEL: Record<ReportTarget, string> = {
  PROFILE: 'Profile', PARTICIPANT: 'Participant', MESSAGE: 'Message', CONVERSATION: 'Conversation', PLAN: 'Plan',
  GROUP: 'Group', ORGANIZER: 'Organizer', EVENT: 'Event', PROBLEM: 'Problem',
};

export const TYPE_ICON: Record<ReportTarget, IconName> = {
  PROFILE: 'user', PARTICIPANT: 'user', MESSAGE: 'message-circle', CONVERSATION: 'message-circle', PLAN: 'calendar',
  GROUP: 'users', ORGANIZER: 'users', EVENT: 'calendar', PROBLEM: 'flag',
};
