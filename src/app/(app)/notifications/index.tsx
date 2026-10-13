import { router } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { notificationsApi, type AppNotification, type NotificationCategory } from '@/api';
import { ActionSheet } from '@/components/Sheet';
import {
  Avatar, Banner, Button, Diff, ErrorBlock, Icon, IconButton, IconTile, Screen, SegmentTabs, Skeleton, StateBlock, T, goBack, type IconName,
} from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { useFocusData } from '@/hooks/useAsync';
import { openDestination } from '@/lib/destination';
import { relativeTime, sectionFor, type Section } from '@/lib/format';
import { enablePush, getPushPermission, type PushPermission } from '@/lib/push';
import { colors, fonts, type PillTone } from '@/theme';
import { tr, translateServer, useLanguage } from '@/i18n';

type Tab = 'ALL' | NotificationCategory;
const SECTIONS: Section[] = ['Today', 'Yesterday', 'This week', 'Earlier'];

const ICONS: Record<string, IconName> = {
  clock: 'clock', calendar: 'calendar', megaphone: 'volume-2', users: 'users', close: 'x', lock: 'lock', spark: 'star', shield: 'shield', check: 'check',
};

function toneFor(n: AppNotification): PillTone {
  if (n.icon === 'close') return 'bad';
  if (n.icon === 'lock') return 'ink';
  if (n.priority === 'LOW') return 'neutral';
  if (n.priority === 'HIGH') return 'blue';
  if (n.icon === 'clock') return 'lime';
  return 'ok';
}

export default function Notifications() {
  useLanguage();
  const { refreshUser } = useAuth();
  const [tab, setTab] = useState<Tab>('ALL');
  const [menu, setMenu] = useState<AppNotification | null>(null);
  const [permission, setPermission] = useState<PushPermission | null>(null);
  const [permDismissed, setPermDismissed] = useState(false);
  const { data, setData, error, loading, refreshing, refresh } = useFocusData(() => notificationsApi.list());

  useEffect(() => {
    void getPushPermission().then(setPermission);
  }, []);

  const list = data ?? [];
  const shown = list.filter((n) => tab === 'ALL' || n.category === tab);
  const unreadIn = (c: Tab) => list.filter((n) => !n.read && (c === 'ALL' || n.category === c)).length;
  const anyUnread = unreadIn('ALL') > 0;

  const setRead = (id: number, read: boolean) => {
    setData((d) => d?.map((n) => (n.id === id ? { ...n, read } : n)) ?? d);
    void notificationsApi.markRead(id, read).then(() => refreshUser()).catch(() => undefined);
  };

  const open = (n: AppNotification) => {
    if (!n.read) setRead(n.id, true);
    openDestination(n);
  };

  const markAll = async () => {
    setData((d) => d?.map((n) => ({ ...n, read: true })) ?? d);
    await notificationsApi.markAllRead().catch(() => undefined);
    void refreshUser();
  };

  return (
    <Screen padded={false} refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.brand} />}>
      <View style={styles.header}>
        <IconButton name="chevron-left" label={tr('Back')} onPress={goBack} />
        <View style={{ flex: 1 }}>
          <T variant="kicker">{tr('USEFUL UPDATES ONLY')}</T>
          <T variant="title" style={{ fontSize: 22 }}>{tr('Notifications')}</T>
        </View>
        <Button label={tr('Mark all read')} kind="text" compact disabled={!anyUnread} onPress={markAll} />
        <IconButton name="settings" label={tr('Notification settings')} onPress={() => router.push('/notifications/settings')} />
      </View>
      <SegmentTabs
        tabs={[
          { key: 'ALL', label: tr('All') },
          { key: 'PLANS', label: tr('Plans'), count: unreadIn('PLANS') },
          { key: 'PEOPLE', label: tr('People'), count: unreadIn('PEOPLE') },
          { key: 'SAFETY', label: tr('Safety'), count: unreadIn('SAFETY') },
        ]}
        value={tab}
        onChange={setTab}
      />

      <View style={{ paddingHorizontal: 16, paddingTop: 14 }}>
        {error?.isNetwork && data ? (
          <View style={{ marginBottom: 12 }}>
            <Banner icon="wifi-off" tone="neutral" title={tr('You’re offline')} body={tr('We’ll show new notifications when your connection returns. Showing saved updates.')} action={tr('Retry')} onAction={refresh} />
          </View>
        ) : null}

        {permission === 'undetermined' && !permDismissed ? (
          <View style={styles.perm}>
            <View style={{ flexDirection: 'row', gap: 12 }}>
              <IconTile name="bell" />
              <View style={{ flex: 1 }}>
                <T variant="bodyStrong">{tr('Stay updated on your Plans')}</T>
                <T variant="small" style={{ marginTop: 2 }}>{tr('Get a push when a Plan changes, someone messages or connects with you, or your group posts an update.')}</T>
              </View>
            </View>
            <View style={{ flexDirection: 'row', gap: 8, marginTop: 12 }}>
              <Button label={tr('Enable notifications')} compact onPress={async () => setPermission(await enablePush())} style={{ flex: 1 }} />
              <Button label={tr('Not now')} kind="secondary" compact onPress={() => setPermDismissed(true)} />
            </View>
          </View>
        ) : null}

        {loading ? <Skeleton rows={4} /> : error && !data ? (
          <ErrorBlock error={error} onRetry={refresh} title={tr('Couldn’t load notifications')} />
        ) : !shown.length ? (
          <StateBlock icon="bell" title={tr('You’re all caught up')} body={tr('Important updates about your Plans, connections and conversations will appear here.')} />
        ) : (
          <>
            {!anyUnread ? (
              <Banner icon="check" title={tr('You’re all caught up')} body={tr('New updates about your Plans will appear here.')} />
            ) : null}
            {SECTIONS.map((sec) => {
              const items = shown.filter((n) => sectionFor(n.createdAt) === sec);
              if (!items.length) return null;
              return (
                <View key={sec} accessibilityLabel={tr(sec)}>
                  <T variant="section">{tr(sec).toUpperCase()}</T>
                  <View style={{ gap: 8 }}>
                    {items.map((n) => <NotificationItem key={n.id} n={n} onOpen={() => open(n)} onMore={() => setMenu(n)} />)}
                  </View>
                </View>
              );
            })}
            <View style={{ flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: 6, paddingVertical: 22 }}>
              <Icon name="check" size={13} color={colors.brand} />
              <T variant="small">{tr('That’s everything. Notifications do not become a feed.')}</T>
            </View>
          </>
        )}
      </View>

      <ActionSheet
        visible={!!menu}
        onClose={() => setMenu(null)}
        title={menu?.title ?? ''}
        actions={menu ? [
          { label: menu.read ? tr('Mark as unread') : tr('Mark as read'), icon: 'check', onPress: () => setRead(menu.id, !menu.read) },
          { label: tr('Notification settings'), icon: 'settings', onPress: () => router.push('/notifications/settings') },
        ] : []}
      />
    </Screen>
  );
}

function NotificationItem({ n: raw, onOpen, onMore }: { n: AppNotification; onOpen: () => void; onMore: () => void }) {
  const lang = useLanguage();
  // Notification text is stored in English; show it in the app language (names, titles and quotes pass through).
  const n = useMemo(() => ({
    ...raw,
    title: translateServer(raw.title, lang),
    body: raw.body ? translateServer(raw.body, lang) : raw.body,
    context: raw.context ? translateServer(raw.context, lang) : raw.context,
    cta: translateServer(raw.cta, lang),
  }), [raw, lang]);
  const pill = n.priority === 'HIGH' ? tr('Important') : n.priority === 'LOW' ? tr('Suggestion') : null;
  return (
    <Pressable
      onPress={onOpen}
      accessibilityRole="button"
      accessibilityLabel={`${n.read ? '' : tr('New. ')}${n.title}. ${n.body ?? n.quote ?? ''}. ${n.cta}`}
      style={({ pressed }) => [styles.item, !n.read && styles.unread, pressed && { opacity: 0.92 }]}
    >
      {n.actor ? <Avatar name={n.actor.displayName} photoUrl={n.actor.photoUrl} id={n.actor.id} size={40} /> : <IconTile name={ICONS[n.icon] ?? 'bell'} tone={toneFor(n)} size={40} />}
      <View style={{ flex: 1, gap: 4 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          {pill ? <Text style={[styles.pill, pill === 'Suggestion' && { backgroundColor: colors.divider, color: colors.inkSoft }]}>{pill}</Text> : null}
          <T variant="caption">{relativeTime(n.createdAt)}</T>
          {!n.read ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
              <View style={styles.dot} />
              <Text style={styles.newText}>{tr('New')}</Text>
            </View>
          ) : null}
        </View>
        <Text style={styles.title}>{n.title}</Text>
        {n.body ? <T variant="small">{n.body}</T> : null}
        {n.quote ? <Text style={styles.quote}>{n.quote}</Text> : null}
        {n.diff.length ? <Diff changes={n.diff} /> : null}
        {n.context ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
            <Icon name="link" size={10} color={colors.inkSoft} />
            <T variant="caption">{n.context}</T>
          </View>
        ) : null}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 }}>
          <Text style={styles.cta}>{n.cta}</Text>
          <Icon name="arrow-right" size={12} color={colors.brand} />
        </View>
      </View>
      <IconButton name="more-horizontal" label={tr('More options for {title}', { title: n.title })} onPress={onMore} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 8, paddingVertical: 8 },
  perm: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, padding: 14, marginBottom: 10 },
  item: { flexDirection: 'row', gap: 12, padding: 13, borderRadius: 18, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line },
  unread: { borderColor: '#bcd9cc', backgroundColor: '#fbfdfb' },
  pill: { fontFamily: fonts.bodyBold, fontSize: 10, color: '#2b5c74', backgroundColor: '#e0edf2', borderRadius: 999, paddingHorizontal: 7, paddingVertical: 2, overflow: 'hidden' },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.brand },
  newText: { fontFamily: fonts.bodyBold, fontSize: 10, color: colors.brand },
  title: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink, lineHeight: 19 },
  quote: { fontFamily: fonts.body, fontStyle: 'italic', fontSize: 12, color: colors.inkSoft, backgroundColor: colors.paper, borderRadius: 10, padding: 8 },
  cta: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.brand },
});
