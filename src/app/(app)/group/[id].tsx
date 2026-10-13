import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { chatApi, plansApi, safetyApi, type PlanMember } from '@/api';
import { Composer } from '@/components/Composer';
import { ActionSheet, ConfirmDialog } from '@/components/Sheet';
import { Avatar, Button, ErrorBlock, Icon, IconButton, IconTile, Loading, Pill, SegmentTabs, T, goBack } from '@/components/ui';
import { useToast } from '@/context/ToastContext';
import { useConversation, type LocalMessage } from '@/hooks/useConversation';
import { firstName, messageTime, relativeTime, topSignal } from '@/lib/format';
import { openReport } from '@/lib/report';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

const ROLE = { CREATOR: 'Creator', ORGANIZER: 'Organizer', PARTICIPANT: 'Participant' } as const;

export default function PlanGroup() {
  useLanguage();
  const { id } = useLocalSearchParams<{ id: string }>();
  const toast = useToast();
  const { detail, setDetail, messages, firstUnreadId, error, loading, reload, send } = useConversation(Number(id));
  const [tab, setTab] = useState<'chat' | 'people'>('chat');
  const [menu, setMenu] = useState(false);
  const [member, setMember] = useState<PlanMember | null>(null);
  const [msgMenu, setMsgMenu] = useState<LocalMessage | null>(null);
  const [confirm, setConfirm] = useState<{ kind: 'block' | 'remove' | 'leave'; member?: PlanMember } | null>(null);
  const scroll = useRef<ScrollView>(null);

  useEffect(() => {
    if (tab === 'chat') setTimeout(() => scroll.current?.scrollToEnd({ animated: false }), 50);
  }, [messages.length, tab]);

  if (loading) return <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper }}><Loading /></SafeAreaView>;
  if (!detail) return <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper, padding: 16 }}>{error ? <ErrorBlock error={error} onRetry={reload} /> : null}</SafeAreaView>;

  const me = detail.members.find((m) => m.me);
  const owner = me?.role === 'CREATOR' || me?.role === 'ORGANIZER';
  const unreadCount = firstUnreadId ? messages.filter((m) => m.id >= firstUnreadId && !m.mine).length : 0;
  let unreadShown = false;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.paper }} edges={['top', 'bottom']}>
      <View style={styles.header}>
        <IconButton name="chevron-left" label={tr('Back')} onPress={goBack} />
        <View style={{ flex: 1 }}>
          <T variant="kicker">{tr('TEMPORARY PLAN GROUP')}</T>
          <Text style={styles.title} numberOfLines={1}>{detail.planTitle ?? detail.title}</Text>
          <T variant="caption">{tr('{n} participants', { n: detail.members.length })}{detail.muted ? ` · ${tr('Muted')}` : ''}</T>
          {detail.official ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
              <Icon name="check" size={10} color={colors.brand} />
              <T variant="caption" style={{ color: colors.brand }}>{tr('Official event · Organizer verified')}</T>
            </View>
          ) : null}
        </View>
        <IconButton name="more-horizontal" label={tr('Group options')} onPress={() => setMenu(true)} />
      </View>

      <View style={styles.planLine}>
        <IconTile name="calendar" size={32} />
        <View style={{ flex: 1 }}>
          <T variant="kicker" style={{ color: colors.inkSoft }}>{tr('PLAN GROUP')}</T>
          <T variant="bodyStrong" numberOfLines={1}>{detail.planLine}</T>
        </View>
        <Button label={tr('View Plan')} compact kind="secondary" onPress={() => router.push(`/plan/${detail.planId}`)} />
      </View>

      {detail.archived ? (
        <View style={styles.archived} accessibilityRole="text">
          <Icon name="lock" size={13} color={colors.inkSoft} />
          <T variant="small" style={{ flex: 1 }}>{detail.archivedReason ?? tr('This Plan Group is archived and read-only.')}</T>
        </View>
      ) : null}

      {detail.announcement ? (
        <View style={styles.announcement} accessibilityLabel={tr('Pinned announcement')}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <Text style={styles.annKicker}>{tr('IMPORTANT ANNOUNCEMENT')}</Text>
            <T variant="caption">{relativeTime(detail.announcement.at)}</T>
          </View>
          <Text style={styles.annBody}><Text style={{ fontFamily: fonts.bodyBold }}>{detail.announcement.title}</Text> {detail.announcement.body}</Text>
          <T variant="caption">{detail.announcement.by} {tr('· Pinned')}</T>
        </View>
      ) : null}

      <SegmentTabs tabs={[{ key: 'chat', label: tr('Chat') }, { key: 'people', label: tr('Participants · {v}', { v: detail.members.length }) }]} value={tab} onChange={setTab} />

      <ScrollView ref={scroll} contentContainerStyle={{ padding: 16, gap: 10 }} keyboardShouldPersistTaps="handled">
        {tab === 'chat' ? (
          <>
            {!messages.length ? <T variant="small" style={{ textAlign: 'center' }}>{tr('No messages yet. Say hi to the group.')}</T> : null}
            {messages.map((m) => {
              const showUnread = !unreadShown && firstUnreadId != null && m.id >= firstUnreadId && !m.mine;
              if (showUnread) unreadShown = true;
              return (
                <View key={m.clientId ?? m.id}>
                  {showUnread ? (
                    <View style={styles.unread}><View style={styles.rule} /><Text style={styles.unreadText}>{unreadCount === 1 ? tr('1 new message') : tr('{n} new messages', { n: unreadCount })}</Text><View style={styles.rule} /></View>
                  ) : null}
                  {m.system ? (
                    <Text style={styles.system}>{m.text}</Text>
                  ) : (
                    <Pressable
                      onPress={() => (m.failed ? send(m.text, m) : !m.mine && !m.removed ? setMsgMenu(m) : undefined)}
                      style={{ flexDirection: 'row', gap: 10 }}
                      accessibilityLabel={`${m.mine ? tr('You') : m.sender?.displayName}: ${m.removed ? tr('Message removed') : m.text}`}
                    >
                      <Avatar name={m.removed ? '?' : m.sender?.displayName ?? tr('You')} id={m.sender?.id ?? 0} size={32} />
                      <View style={{ flex: 1 }}>
                        <T variant="caption">{m.mine ? tr('You') : m.removed ? tr('Removed') : m.sender?.displayName} · {m.failed ? tr('Not sent · tap to retry') : m.pending ? tr('Sending…') : messageTime(m.createdAt)}</T>
                        <View style={[styles.bubble, m.mine && { backgroundColor: colors.brandPale, borderColor: '#bcd9cc' }]}>
                          <Text style={[styles.text, m.removed && { fontStyle: 'italic', color: colors.inkSoft }]}>{m.removed ? tr('This message was removed') : m.text}</Text>
                        </View>
                      </View>
                    </Pressable>
                  )}
                </View>
              );
            })}
          </>
        ) : (
          <View style={styles.members}>
            {detail.members.map((mb, i) => {
              const sig = topSignal(mb.user.signals);
              return (
                <View key={mb.user.id} style={[styles.member, i > 0 && { borderTopWidth: 1, borderTopColor: colors.divider }]}>
                  <Pressable onPress={() => !mb.me && router.push(`/user/${mb.user.id}`)} style={{ flexDirection: 'row', alignItems: 'center', gap: 10, flex: 1 }}>
                    <Avatar name={mb.user.displayName} photoUrl={mb.user.photoUrl} id={mb.user.id} size={38} />
                    <View style={{ flex: 1, gap: 3 }}>
                      <T variant="bodyStrong">{mb.me ? tr('You') : mb.user.displayName}</T>
                      {sig ? <Pill label={sig} icon="check" tone="ok" /> : null}
                    </View>
                  </Pressable>
                  <T variant="caption">{ROLE[mb.role]}</T>
                  {!mb.me ? <IconButton name="more-horizontal" label={tr('Options for {displayName}', { displayName: mb.user.displayName })} onPress={() => setMember(mb)} /> : null}
                </View>
              );
            })}
          </View>
        )}
      </ScrollView>

      {detail.canSend ? <Composer onSend={(t) => send(t)} placeholder={tr('Message the group…')} note={tr('Visible to approved Plan participants only.')} /> : null}

      <ActionSheet
        visible={menu}
        onClose={() => setMenu(false)}
        title={detail.planTitle ?? detail.title}
        actions={[
          { label: tr('View Plan'), icon: 'calendar', onPress: () => router.push(`/plan/${detail.planId}`) },
          { label: detail.muted ? tr('Unmute group') : tr('Mute group'), icon: detail.muted ? 'bell' : 'bell-off', onPress: async () => { await chatApi.mute(detail.id, !detail.muted); setDetail({ ...detail, muted: !detail.muted }); } },
          ...(owner && detail.planId ? [{ label: tr('Post an announcement'), icon: 'volume-2' as const, onPress: () => router.push(`/plan/${detail.planId}/announce`) }] : []),
          { label: tr('Report group'), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: () => openReport({ targetType: 'GROUP', targetId: detail.id, title: detail.planTitle ?? detail.title, sub: tr('Plan Group') }) },
          ...(!owner && !detail.archived ? [{ label: tr('Leave Plan'), icon: 'log-out' as const, danger: true, onPress: () => setConfirm({ kind: 'leave' }) }] : []),
        ]}
      />
      <ActionSheet
        visible={!!member}
        onClose={() => setMember(null)}
        title={member?.user.displayName ?? ''}
        sub={member ? ROLE[member.role] : null}
        actions={member ? [
          { label: tr('View profile'), icon: 'user', onPress: () => router.push(`/user/${member.user.id}`) },
          { label: tr('Report {v}', { v: firstName(member.user.displayName) }), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: () => openReport({ targetType: 'PARTICIPANT', targetId: member.user.id, title: member.user.displayName, sub: tr('Participant in {planTitle}', { planTitle: detail.planTitle }), personId: member.user.id, personName: firstName(member.user.displayName) }) },
          { label: tr('Block {v}', { v: firstName(member.user.displayName) }), icon: 'slash', danger: true, onPress: () => setConfirm({ kind: 'block', member }) },
          ...(owner && member.role === 'PARTICIPANT' ? [{ label: tr('Remove from Plan'), icon: 'user-x' as const, danger: true, sub: tr('They’re told privately'), onPress: () => setConfirm({ kind: 'remove', member }) }] : []),
        ] : []}
      />
      <ActionSheet
        visible={!!msgMenu}
        onClose={() => setMsgMenu(null)}
        title={tr('Message from {v}', { v: msgMenu?.sender?.displayName ?? '' })}
        quote={msgMenu?.text}
        actions={msgMenu ? [{ label: tr('Report message'), icon: 'flag', danger: true, sub: tr('Reports are private'), onPress: () => openReport({ targetType: 'MESSAGE', targetId: msgMenu.id, title: tr('A message from {v}', { v: msgMenu.sender?.displayName }), sub: detail.planTitle, quote: msgMenu.text, personId: msgMenu.sender?.id, personName: firstName(msgMenu.sender?.displayName ?? '') }) }] : []}
      />
      <ConfirmDialog
        visible={confirm?.kind === 'block'}
        onClose={() => setConfirm(null)}
        title={tr('Block {v}?', { v: firstName(confirm?.member?.user.displayName ?? '') })}
        body={tr('They won’t be able to message you or send requests. You’ll still both be in this Plan unless one of you leaves. They won’t be told.')}
        okLabel={tr('Block')} okKind="dangerSolid" icon="slash" tone="bad"
        onConfirm={async () => { if (confirm?.member) { await safetyApi.block(confirm.member.user.id); toast(tr('Blocked')); } }}
      />
      <ConfirmDialog
        visible={confirm?.kind === 'remove'}
        onClose={() => setConfirm(null)}
        title={tr('Remove from Plan?')}
        body={tr('They’ll leave the Plan and its group, and be told privately. They can’t rejoin this Plan.')}
        okLabel={tr('Remove')} okKind="dangerSolid" icon="user-x" tone="bad"
        onConfirm={async () => { if (confirm?.member && detail.planId) { await plansApi.removeParticipant(detail.planId, confirm.member.user.id); await reload(); } }}
      />
      <ConfirmDialog
        visible={confirm?.kind === 'leave'}
        onClose={() => setConfirm(null)}
        title={tr('Leave this Plan?')}
        body={tr('You’ll leave the Plan Group too. Connections you made stay with you.')}
        okLabel={tr('Leave Plan')} okKind="dangerSolid" icon="log-out" tone="bad"
        onConfirm={async () => { if (detail.planId) { await plansApi.leave(detail.planId); router.replace('/chats'); } }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 8, paddingVertical: 8 },
  title: { fontFamily: fonts.display, fontSize: 17, color: colors.ink },
  planLine: { flexDirection: 'row', alignItems: 'center', gap: 10, marginHorizontal: 16, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 16, padding: 10 },
  archived: { flexDirection: 'row', alignItems: 'center', gap: 8, marginHorizontal: 16, marginTop: 10, backgroundColor: colors.muted, borderRadius: 12, padding: 10 },
  announcement: { marginHorizontal: 16, marginTop: 10, backgroundColor: '#e0edf2', borderRadius: 16, padding: 12, gap: 4 },
  annKicker: { fontFamily: fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: '#2b5c74' },
  annBody: { fontFamily: fonts.body, fontSize: 13, lineHeight: 19, color: colors.ink },
  unread: { flexDirection: 'row', alignItems: 'center', gap: 8, marginVertical: 6 },
  rule: { flex: 1, height: 1, backgroundColor: colors.brand, opacity: 0.4 },
  unreadText: { fontFamily: fonts.bodyBold, fontSize: 11, color: colors.brand },
  system: { alignSelf: 'center', textAlign: 'center', fontFamily: fonts.bodySemi, fontSize: 12, color: colors.inkSoft, backgroundColor: colors.muted, borderRadius: 12, padding: 8 },
  bubble: { alignSelf: 'flex-start', maxWidth: '92%', backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 16, borderTopLeftRadius: 6, paddingHorizontal: 12, paddingVertical: 8, marginTop: 3 },
  text: { fontFamily: fonts.body, fontSize: 14, lineHeight: 20, color: colors.ink },
  members: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 18, overflow: 'hidden' },
  member: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 10 },
});
