import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { chatApi, safetyApi } from '@/api';
import { Composer } from '@/components/Composer';
import { ActionSheet, ConfirmDialog } from '@/components/Sheet';
import { Avatar, Button, ErrorBlock, Icon, IconButton, IconTile, Loading, Pill, T, goBack } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useConversation, type LocalMessage } from '@/hooks/useConversation';
import { dayLabel, firstName, messageTime, topSignal } from '@/lib/format';
import { openReport } from '@/lib/report';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function DirectChat() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const toast = useToast();
  const { detail, setDetail, messages, firstUnreadId, error, loading, reload, send } = useConversation(Number(id));
  const [menu, setMenu] = useState(false);
  const [msgMenu, setMsgMenu] = useState<LocalMessage | null>(null);
  const [confirmBlock, setConfirmBlock] = useState(false);
  const scroll = useRef<ScrollView>(null);

  useEffect(() => {
    setTimeout(() => scroll.current?.scrollToEnd({ animated: false }), 50);
  }, [messages.length]);

  if (loading) return <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper }}><Loading /></SafeAreaView>;
  if (!detail) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper, padding: 16 }}>
        {error?.status === 404 || error?.status === 410 ? (
          <ErrorBlock error={{ message: tr('This conversation is no longer available.') }} onRetry={goBack} title={tr('Conversation unavailable')} />
        ) : error ? <ErrorBlock error={error} onRetry={reload} /> : null}
      </SafeAreaView>
    );
  }

  const other = detail.otherUser;
  const name = other?.displayName ?? detail.title;
  const first = firstName(name);
  const sig = other ? topSignal(other.signals) : null;

  let lastDay = '';
  let unreadShown = false;
  const unreadCount = firstUnreadId ? messages.filter((m) => m.id >= firstUnreadId && !m.mine).length : 0;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper }} edges={['top', 'bottom']}>
      <View style={styles.header}>
        <IconButton name="chevron-left" label={tr('Back')} onPress={goBack} />
        <Pressable style={{ flexDirection: 'row', alignItems: 'center', gap: 10, flex: 1 }} onPress={() => other && router.push(`/user/${other.id}`)} accessibilityRole="button" accessibilityLabel={tr('View {name}’s profile', { name })}>
          <Avatar name={name} photoUrl={other?.photoUrl} id={other?.id ?? 0} size={38} />
          <View style={{ flex: 1 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Text style={styles.name} numberOfLines={1}>{name}</Text>
              {sig ? <Pill label={sig} icon="check" tone="ok" /> : null}
            </View>
            {detail.context ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                <Icon name="link" size={10} color={colors.inkSoft} />
                <T variant="caption" numberOfLines={1}>{detail.context}</T>
              </View>
            ) : null}
          </View>
        </Pressable>
        <IconButton name="more-horizontal" label={tr('Conversation options')} onPress={() => setMenu(true)} />
      </View>

      <ScrollView ref={scroll} contentContainerStyle={{ padding: 16, gap: 6 }} keyboardShouldPersistTaps="handled">
        {detail.planId && detail.planLine ? (
          <Pressable onPress={() => router.push(`/plan/${detail.planId}`)} style={styles.plan} accessibilityRole="button">
            <IconTile name="calendar" size={34} />
            <View style={{ flex: 1 }}>
              <T variant="kicker" style={{ color: colors.inkSoft }}>{tr('SHARED PLAN')}</T>
              <T variant="bodyStrong" numberOfLines={1}>{detail.planLine}</T>
            </View>
            <Text style={styles.view}>{tr('View')}</Text>
          </Pressable>
        ) : null}

        {!messages.length ? <T variant="small" style={{ textAlign: 'center', marginTop: 20 }}>{tr('{context}. Say hello.', { context: detail.context ?? tr('You’re connected') })}</T> : null}

        {messages.map((m) => {
          const day = dayLabel(m.createdAt);
          const showDay = day !== lastDay;
          lastDay = day;
          const showUnread = !unreadShown && firstUnreadId != null && m.id >= firstUnreadId && !m.mine;
          if (showUnread) unreadShown = true;
          return (
            <View key={m.clientId ?? m.id}>
              {showDay ? <Text style={styles.day}>{day}</Text> : null}
              {showUnread ? (
                <View style={styles.unread} accessibilityRole="text" accessibilityLabel={tr('{unreadCount} new messages', { unreadCount })}>
                  <View style={styles.rule} /><Text style={styles.unreadText}>{unreadCount === 1 ? tr('1 new message') : tr('{n} new messages', { n: unreadCount })}</Text><View style={styles.rule} />
                </View>
              ) : null}
              {m.system ? (
                <Text style={styles.system}>{m.text}</Text>
              ) : (
                <View style={{ alignItems: m.mine ? 'flex-end' : 'flex-start' }}>
                  <Pressable
                    onPress={() => (m.failed ? send(m.text, m) : !m.mine && !m.removed ? setMsgMenu(m) : undefined)}
                    accessibilityRole={!m.mine || m.failed ? 'button' : 'text'}
                    accessibilityLabel={`${m.mine ? tr('You') : first}: ${m.removed ? tr('Message removed') : m.text}, ${messageTime(m.createdAt)}${m.failed ? tr(', not sent, tap to retry') : ''}`}
                    style={[styles.bubble, m.mine ? styles.mine : styles.theirs, m.failed && { borderColor: colors.danger, borderWidth: 1 }]}
                  >
                    <Text style={[styles.text, m.mine && { color: '#fff' }, m.removed && { fontStyle: 'italic', opacity: 0.7 }]}>{m.removed ? tr('Message removed') : m.text}</Text>
                    <Text style={[styles.time, m.mine && { color: 'rgba(255,255,255,0.75)' }]}>
                      {m.failed ? tr('Not sent · tap to retry') : m.pending ? tr('Sending…') : messageTime(m.createdAt)}
                    </Text>
                  </Pressable>
                </View>
              )}
            </View>
          );
        })}
      </ScrollView>

      {detail.blockedByMe ? (
        <View style={styles.blocked} accessibilityRole="text">
          <T variant="small" style={{ flex: 1 }}>{tr('You blocked {name}. You can’t send or receive messages.', { name: first })}</T>
          <Button label={tr('Unblock')} compact kind="secondary" onPress={async () => { if (other) { await safetyApi.unblock(other.id); await reload(); } }} />
        </View>
      ) : detail.canSend ? (
        <Composer onSend={(t) => send(t)} />
      ) : (
        <View style={styles.blocked}><T variant="small">{detail.archivedReason ?? tr('This conversation is read-only.')}</T></View>
      )}

      <ActionSheet
        visible={menu}
        onClose={() => setMenu(false)}
        title={name}
        sub={detail.context}
        actions={[
          ...(other ? [{ label: tr('View profile'), icon: 'user' as const, onPress: () => router.push(`/user/${other.id}`) }] : []),
          { label: detail.muted ? tr('Unmute conversation') : tr('Mute conversation'), icon: detail.muted ? 'bell' : 'bell-off', onPress: async () => { await chatApi.mute(detail.id, !detail.muted); setDetail({ ...detail, muted: !detail.muted }); toast(detail.muted ? tr('Unmuted') : tr('Muted')); } },
          { label: tr('Report conversation'), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: () => openReport({ targetType: 'CONVERSATION', targetId: detail.id, title: tr('Conversation with {first}', { first }), sub: detail.context, personId: other?.id, personName: first }) },
          ...(other && !detail.blockedByMe ? [{ label: tr('Block {first}', { first }), icon: 'slash' as const, danger: true, onPress: () => setConfirmBlock(true) }] : []),
        ]}
      />
      <ActionSheet
        visible={!!msgMenu}
        onClose={() => setMsgMenu(null)}
        title={tr('Message from {first}', { first })}
        quote={msgMenu?.text}
        actions={msgMenu ? [
          { label: tr('Report message'), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: () => openReport({ targetType: 'MESSAGE', targetId: msgMenu.id, title: tr('A message from {name}', { name }), quote: msgMenu.text, personId: other?.id, personName: first }) },
          ...(other ? [{ label: tr('Block {first}', { first }), icon: 'slash' as const, danger: true, onPress: () => setConfirmBlock(true) }] : []),
        ] : []}
      />
      <ConfirmDialog
        visible={confirmBlock}
        onClose={() => setConfirmBlock(false)}
        title={tr('Block {first}?', { first })}
        body={tr('{first} won’t be able to message you, send requests or see your Plans. They won’t be told.', { first })}
        okLabel={tr('Block')}
        okKind="dangerSolid"
        icon="slash"
        tone="bad"
        onConfirm={async () => {
          if (!other) return;
          await safetyApi.block(other.id);
          await reload();
          toast(tr('{first} blocked', { first }));
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 8, paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: colors.line },
  name: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink, flexShrink: 1 },
  plan: { flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 16, padding: 10, marginBottom: 8 },
  view: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.brand },
  day: { alignSelf: 'center', fontFamily: fonts.bodyBold, fontSize: 11, color: colors.inkSoft, backgroundColor: colors.muted, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 4, marginVertical: 8, overflow: 'hidden' },
  unread: { flexDirection: 'row', alignItems: 'center', gap: 8, marginVertical: 8 },
  rule: { flex: 1, height: 1, backgroundColor: colors.brand, opacity: 0.4 },
  unreadText: { fontFamily: fonts.bodyBold, fontSize: 11, color: colors.brand },
  system: { alignSelf: 'center', textAlign: 'center', fontFamily: fonts.bodySemi, fontSize: 12, color: colors.inkSoft, backgroundColor: '#e0edf2', borderRadius: 12, padding: 8, marginVertical: 6 },
  bubble: { maxWidth: '80%', borderRadius: 18, paddingHorizontal: 13, paddingVertical: 9 },
  mine: { backgroundColor: colors.brand, borderBottomRightRadius: 6 },
  theirs: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderBottomLeftRadius: 6 },
  text: { fontFamily: fonts.body, fontSize: 14, lineHeight: 20, color: colors.ink },
  time: { fontFamily: fonts.body, fontSize: 10, color: colors.inkSoft, marginTop: 3, alignSelf: 'flex-end' },
  blocked: { flexDirection: 'row', alignItems: 'center', gap: 10, padding: 14, borderTopWidth: 1, borderTopColor: colors.line, backgroundColor: colors.surface },
});
