import { useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { View } from 'react-native';
import { ApiError, contentApi, type ContentPage } from '@/api';
import { Markdown } from '@/components/Markdown';
import { ErrorBlock, Header, Note, Screen, Skeleton, T } from '@/components/ui';
import { tr, useLanguage } from '@/i18n';

const TITLES: Record<string, string> = {
  privacy: 'Privacy policy',
  terms: 'Terms of service',
  'refund-policy': 'Refund policy',
  'cookie-policy': 'Cookie & storage policy',
  faq: 'Help & FAQ',
};

/** A policy page, edited by the team in the Admin Console (Content → Pages & policies). */
export default function LegalPage() {
  useLanguage();
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const [page, setPage] = useState<ContentPage | null>(null);
  const [error, setError] = useState<ApiError | null>(null);

  const load = useCallback(() => {
    setError(null);
    contentApi.page(slug).then(setPage).catch((e) => setError(e instanceof ApiError ? e : new ApiError(0, 'ERROR', tr('Couldn’t load this'))));
  }, [slug]);
  useEffect(load, [load]);

  const title = page?.title ?? tr(TITLES[slug] ?? 'Policy');
  const draft = !!page && /\[[^\]]+\]/.test(page.body);

  return (
    <Screen>
      <Header kicker={tr('LEGAL')} title={title} />
      {error ? (
        <ErrorBlock
          error={error.status === 404 ? { message: tr('This page isn’t published yet.') } : error}
          title={tr('Couldn’t load this page')}
          onRetry={load}
        />
      ) : !page ? (
        <Skeleton rows={5} />
      ) : (
        <View style={{ gap: 14, paddingTop: 4 }}>
          {draft ? <Note icon="info">{tr('Some details on this page (shown in [brackets]) are still being completed.')}</Note> : null}
          <Markdown text={page.body} />
          <T variant="caption" style={{ marginTop: 8 }}>
            {tr('Last changed {date}', { date: new Date(page.updatedAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' }) })}
          </T>
        </View>
      )}
    </Screen>
  );
}
