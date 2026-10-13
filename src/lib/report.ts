import { router } from 'expo-router';
import type { ReportTarget } from '@/api/types';

export interface ReportParams {
  targetType: ReportTarget;
  targetId?: number | null;
  /** What is being reported, shown at the top of the flow ("Aarav P.’s profile"). */
  title: string;
  sub?: string | null;
  quote?: string | null;
  /** Person who can optionally be blocked in the same flow. */
  personId?: number | null;
  personName?: string | null;
}

export function openReport(p: ReportParams) {
  router.push({
    pathname: '/report',
    params: {
      targetType: p.targetType,
      targetId: p.targetId != null ? String(p.targetId) : '',
      title: p.title,
      sub: p.sub ?? '',
      quote: p.quote ?? '',
      personId: p.personId != null ? String(p.personId) : '',
      personName: p.personName ?? '',
    },
  });
}
