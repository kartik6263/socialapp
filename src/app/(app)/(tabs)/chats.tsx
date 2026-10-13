import { router } from 'expo-router';
import { Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { chatApi, type ConversationSummary } from '@/api';
import { Avatar, ErrorBlock, Group, Headline, Icon, Screen, SectionTitle, Skeleton, StateBlock, T } from '@/components/ui';
import { useFocusData } from '@/hooks/useAsync';
import { relativeTime } from '@/lib/format';
import { colors, fonts } from '@/theme';
import { tr, useLanguage } from '@/i18n';

export default function Chats() {
  useLanguage();
  const { data, error, loading, refreshing, refresh } = useFocusData(() => chatApi.list());
  const groups = data?.filter((c) => c.type === 'GROUP') ?? [];
  const direct = data?.filter((c) => c.type === 'DIRECT') ?? [];

  const open = (c: ConversationSummary) => router.push(c.type === 'GROUP' ? `/group/${c.id}` : `/chat/${c.id}`);

  return (
    <Screen refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.brand} />}>
      <View style={{ paddingTop: 20 }}>
        <T variant="kicker">{tr('CONVERSATIONS WITH CONTEXT')}</T>
        <View style={{ marginTop: 8 }}><Headline text={tr('Chats')} size="title" /></View>
      </View>
      {loading ? <Skeleton /> : error && !data ? <ErrorBlock error={error} onRetry={refresh} /> : !data?.length ? (
        <StateBlock icon="message-circle" title={tr('No conversations yet')} body={tr('Chats open when someone accepts your connection, or when you join a Plan with a group.')} actions={[{ label: tr('Discover plans'), onPress: () => router.navigate('/') }]} />
      ) : (
        <>
          {groups.length ? (
            <>
              <SectionTitle title={tr('Plan groups')} />
              <Group>{groups.map((c, i) => <ChatRow key={c.id} c={c} first={i === 0} onPress={() => open(c)} />)}</Group>
            </>
          ) : null}
          {direct.length ? (
            <>
              <SectionTitle title={tr('Direct messages')} />
              <Group>{direct.map((c, i) => <ChatRow key={c.id} c={c} first={i === 0} onPress={() => open(c)} />)}</Group>
            </>
          ) : null}
          <T variant="small" style={{ textAlign: 'center', marginTop: 20 }}>{tr('Phone numbers are never shared in chats.')}</T>
        </>
      )}
    </Screen>
  );
}

function ChatRow({ c, first, onPress }: { c: ConversationSummary; first: boolean; onPress: () => void }) {
  useLanguage();
  const preview = c.lastMessage ? (c.lastMessage.removed ? tr('Message removed') : `${c.type === 'GROUP' && c.lastMessage.sender && !c.lastMessage.mine ? `${c.lastMessage.sender.displayName.split(' ')[0]}: ` : c.lastMessage.mine ? 'You: ' : ''}${c.lastMessage.text}`) : c.context ?? tr('Say hello');
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={`${c.title}${c.unread ? tr(', {unread} unread', { unread: c.unread }) : ''}`} style={({ pressed }) => [styles.row, !first && styles.divider, pressed && { backgroundColor: colors.paper }]}>
      {c.type === 'GROUP' ? (
        <View style={styles.groupIcon}><Icon name="users" size={18} color={colors.brand} /></View>
      ) : (
        <Avatar name={c.otherUser?.displayName ?? c.title} photoUrl={c.otherUser?.photoUrl} id={c.otherUser?.id ?? c.id} size={44} />
      )}
      <View style={{ flex: 1, gap: 2 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <Text style={styles.title} numberOfLines={1}>{c.title}</Text>
          {c.muted ? <Icon name="bell-off" size={12} color={colors.inkSoft} /> : null}
          {c.lastMessage ? <T variant="caption" style={{ marginLeft: 'auto' }}>{relativeTime(c.lastMessage.createdAt)}</T> : null}
        </View>
        {c.context ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
            <Icon name="link" size={10} color={colors.brand} />
            <T variant="caption" style={{ color: colors.brand }} numberOfLines={1}>{c.context}</T>
          </View>
        ) : null}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Text style={[styles.preview, c.unread > 0 && { color: colors.ink, fontFamily: fonts.bodySemi }]} numberOfLines={1}>{preview}</Text>
          {c.unread > 0 ? <View style={styles.unread}><Text style={styles.unreadText}>{c.unread > 9 ? '9+' : c.unread}</Text></View> : null}
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 12 },
  divider: { borderTopWidth: 1, borderTopColor: colors.divider },
  groupIcon: { width: 44, height: 44, borderRadius: 14, backgroundColor: colors.brandPale, alignItems: 'center', justifyContent: 'center' },
  title: { flexShrink: 1, fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  preview: { flex: 1, fontFamily: fonts.body, fontSize: 13, color: colors.inkSoft },
  unread: { minWidth: 20, height: 20, borderRadius: 10, paddingHorizontal: 6, backgroundColor: colors.brand, alignItems: 'center', justifyContent: 'center' },
  unreadText: { color: '#fff', fontFamily: fonts.bodyBold, fontSize: 10 },
});
