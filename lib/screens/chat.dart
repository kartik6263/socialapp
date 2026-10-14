import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/conversation.dart';
import '../state/toast.dart';
import '../util/format.dart';
import '../util/misc.dart';
import '../widgets/parts.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';

const _role = {'CREATOR': 'Creator', 'ORGANIZER': 'Organizer', 'PARTICIPANT': 'Participant'};

/// Owns a Conversation for the lifetime of a chat screen and scrolls to the newest message.
mixin _ChatState<W extends StatefulWidget> on State<W> {
  late final Conversation convo;
  final scroll = ScrollController();
  int _lastCount = -1;

  int get conversationId;

  @override
  void initState() {
    super.initState();
    convo = Conversation(conversationId, authOf(context));
    convo.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (convo.messages.length != _lastCount) {
      _lastCount = convo.messages.length;
      scrollToEnd();
    }
  }

  void scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    convo.removeListener(_changed);
    convo.dispose();
    scroll.dispose();
    super.dispose();
  }
}

Widget _unreadDivider(int unreadCount) => Semantics(
      label: tr('{unreadCount} new messages', {'unreadCount': unreadCount}),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Container(height: 1, color: AppColors.brand.withValues(alpha: 0.4))),
          const SizedBox(width: 8),
          Text(unreadCount == 1 ? tr('1 new message') : tr('{n} new messages', {'n': unreadCount}),
              style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: AppColors.brand)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColors.brand.withValues(alpha: 0.4))),
        ]),
      ),
    );

Widget _systemMessage(String text, Color bg, {double vMargin = 6}) => Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: vMargin),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Fonts.bodySemi, fontSize: 12, color: AppColors.inkSoft)),
      ),
    );

// ---------- Direct chat ----------

class DirectChatScreen extends StatefulWidget {
  final int id;
  const DirectChatScreen({super.key, required this.id});
  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> with _ChatState<DirectChatScreen> {
  @override
  int get conversationId => widget.id;

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    if (convo.loading) return const Scaffold(backgroundColor: AppColors.paper, body: SafeArea(child: Loading()));
    final detail = convo.detail;
    if (detail == null) {
      final error = convo.error;
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: error == null
                ? const SizedBox()
                : (error.status == 404 || error.status == 410)
                    ? ErrorBlock(message: tr('This conversation is no longer available.'), onRetry: goBack, title: tr('Conversation unavailable'))
                    : ErrorBlock.of(error, onRetry: convo.load),
          ),
        ),
      );
    }

    final other = detail.otherUser;
    final name = other?.displayName ?? detail.title;
    final first = firstName(name);
    final sig = other != null ? topSignal(other.signals) : null;
    final firstUnreadId = convo.firstUnreadId;
    final messages = convo.messages;
    final unreadCount = firstUnreadId != null ? messages.where((m) => m.id >= firstUnreadId && !m.mine).length : 0;

    Future<void> confirmBlock() => showConfirm(
          context,
          title: tr('Block {first}?', {'first': first}),
          body: tr('{first} won’t be able to message you, send requests or see your Plans. They won’t be told.', {'first': first}),
          okLabel: tr('Block'),
          okKind: BK.dangerSolid,
          icon: 'slash',
          tone: PillTone.bad,
          onConfirm: () async {
            if (other == null) return;
            await SafetyApi.block(other.id);
            await convo.load();
            toast(tr('{first} blocked', {'first': first}));
          },
        );

    void menu() => showActionSheet(context, title: name, sub: detail.context, actions: [
          if (other != null) SheetAction(tr('View profile'), 'user', () => Nav.push('/user/${other.id}')),
          SheetAction(detail.muted ? tr('Unmute conversation') : tr('Mute conversation'), detail.muted ? 'bell' : 'bell-off', () async {
            await ChatApi.mute(detail.id, !detail.muted);
            convo.setDetail(detail.copyWith({'muted': !detail.muted}));
            toast(detail.muted ? tr('Unmuted') : tr('Muted'));
          }),
          SheetAction(
            tr('Report conversation'),
            'flag',
            () => openReport(ReportParams(
              targetType: 'CONVERSATION',
              targetId: detail.id,
              title: tr('Conversation with {first}', {'first': first}),
              sub: detail.context,
              personId: other?.id,
              personName: first,
            )),
            danger: true,
            sub: tr('Reports are private'),
          ),
          if (other != null && !detail.blockedByMe) SheetAction(tr('Block {first}', {'first': first}), 'slash', confirmBlock, danger: true),
        ]);

    void msgMenu(LocalMessage m) => showActionSheet(context, title: tr('Message from {first}', {'first': first}), quote: m.text, actions: [
          SheetAction(
            tr('Report message'),
            'flag',
            () => openReport(ReportParams(
              targetType: 'MESSAGE',
              targetId: m.id,
              title: tr('A message from {name}', {'name': name}),
              quote: m.text,
              personId: other?.id,
              personName: first,
            )),
            danger: true,
            sub: tr('Reports are private'),
          ),
          if (other != null) SheetAction(tr('Block {first}', {'first': first}), 'slash', confirmBlock, danger: true),
        ]);

    final items = <Widget>[];
    if (detail.planId != null && detail.planLine != null) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Pressable(
          onPress: () => Nav.push('/plan/${detail.planId}'),
          label: '${tr('SHARED PLAN')} ${detail.planLine}',
          focusRadius: BorderRadius.circular(16),
          builder: (_, _, _) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const IconTile('calendar', size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Txt(tr('SHARED PLAN'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                  Txt(detail.planLine, variant: TV.bodyStrong, maxLines: 1),
                ]),
              ),
              const SizedBox(width: 10),
              Text(tr('View'), style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: AppColors.brand)),
            ]),
          ),
        ),
      ));
    }
    if (messages.isEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Txt(tr('{context}. Say hello.', {'context': detail.context ?? tr('You’re connected')}), variant: TV.small, align: TextAlign.center),
      ));
    }
    var lastDay = '';
    var unreadShown = false;
    for (final m in messages) {
      final day = dayLabel(m.createdAt);
      final showDay = day != lastDay;
      lastDay = day;
      final showUnread = !unreadShown && firstUnreadId != null && m.id >= firstUnreadId && !m.mine;
      if (showUnread) unreadShown = true;
      items.add(Column(key: ValueKey(m.key), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showDay)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(999)),
              child: Text(day, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: AppColors.inkSoft)),
            ),
          ),
        if (showUnread) _unreadDivider(unreadCount),
        if (m.system)
          _systemMessage(m.text, const Color(0xFFE0EDF2))
        else
          Align(
            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Pressable(
              onPress: m.failed ? () => convo.send(m.text, m) : (!m.mine && !m.removed ? () => msgMenu(m) : null),
              button: !m.mine || m.failed,
              label: '${m.mine ? tr('You') : first}: ${m.removed ? tr('Message removed') : m.text}, ${messageTime(m.createdAt)}${m.failed ? tr(', not sent, tap to retry') : ''}',
              focusRadius: BorderRadius.circular(18),
              builder: (_, _, _) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8 - 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: m.mine ? AppColors.brand : AppColors.surface,
                    border: m.failed ? Border.all(color: AppColors.danger) : (m.mine ? null : Border.all(color: AppColors.line)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(m.mine ? 18 : 6),
                      bottomRight: Radius.circular(m.mine ? 6 : 18),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      m.removed ? tr('Message removed') : m.text,
                      style: TextStyle(
                        fontFamily: Fonts.body,
                        fontSize: 14,
                        height: 20 / 14,
                        color: (m.mine ? Colors.white : AppColors.ink).withValues(alpha: m.removed ? 0.7 : 1),
                        fontStyle: m.removed ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        m.failed ? tr('Not sent · tap to retry') : (m.pending ? tr('Sending…') : messageTime(m.createdAt)),
                        style: TextStyle(fontFamily: Fonts.body, fontSize: 10, color: m.mine ? const Color.fromRGBO(255, 255, 255, 0.75) : AppColors.inkSoft),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]));
    }

    Widget bottom;
    if (detail.blockedByMe) {
      bottom = Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Expanded(child: Txt(tr('You blocked {name}. You can’t send or receive messages.', {'name': first}), variant: TV.small)),
          const SizedBox(width: 10),
          Button(tr('Unblock'), compact: true, kind: BK.secondary, onPress: () async {
            if (other != null) {
              await SafetyApi.unblock(other.id);
              await convo.load();
            }
          }),
        ]),
      );
    } else if (detail.canSend) {
      bottom = Composer(onSend: (t) => convo.send(t));
    } else {
      bottom = Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
        child: Txt(detail.archivedReason ?? tr('This conversation is read-only.'), variant: TV.small),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
            child: Row(children: [
              IconBtn('chevron-left', label: tr('Back'), onPress: goBack),
              const SizedBox(width: 4),
              Expanded(
                child: Pressable(
                  onPress: other != null ? () => Nav.push('/user/${other.id}') : null,
                  label: tr('View {name}’s profile', {'name': name}),
                  builder: (_, _, _) => Row(children: [
                    Avatar(name: name, photoUrl: other?.photoUrl, id: other?.id ?? 0, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 15, color: AppColors.ink)),
                          ),
                          if (sig != null) ...[const SizedBox(width: 6), Flexible(child: Pill(sig, icon: 'check', tone: PillTone.ok))],
                        ]),
                        if (detail.context != null)
                          Row(children: [
                            const FIcon('link', size: 10, color: AppColors.inkSoft),
                            const SizedBox(width: 4),
                            Expanded(child: Txt(detail.context, variant: TV.caption, maxLines: 1)),
                          ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              IconBtn('more-horizontal', label: tr('Conversation options'), onPress: menu),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              children: gapped(items, 6),
            ),
          ),
          bottom,
        ]),
      ),
    );
  }
}

// ---------- Plan group ----------

class PlanGroupScreen extends StatefulWidget {
  final int id;
  const PlanGroupScreen({super.key, required this.id});
  @override
  State<PlanGroupScreen> createState() => _PlanGroupScreenState();
}

class _PlanGroupScreenState extends State<PlanGroupScreen> with _ChatState<PlanGroupScreen> {
  String tab = 'chat';

  @override
  int get conversationId => widget.id;

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    if (convo.loading) return const Scaffold(backgroundColor: AppColors.paper, body: SafeArea(child: Loading()));
    final detail = convo.detail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: convo.error != null ? ErrorBlock.of(convo.error!, onRetry: convo.load) : const SizedBox(),
          ),
        ),
      );
    }

    final meMember = detail.members.where((m) => m.me).firstOrNull;
    final owner = meMember?.role == 'CREATOR' || meMember?.role == 'ORGANIZER';
    final messages = convo.messages;
    final firstUnreadId = convo.firstUnreadId;
    final unreadCount = firstUnreadId != null ? messages.where((m) => m.id >= firstUnreadId && !m.mine).length : 0;
    // The divider goes above the first unread message from someone else.
    final dividerAt = firstUnreadId == null ? -1 : messages.indexWhere((m) => m.id >= firstUnreadId && !m.mine);

    Future<void> confirmBlock(PlanMember member) => showConfirm(
          context,
          title: tr('Block {v}?', {'v': firstName(member.user.displayName)}),
          body: tr('They won’t be able to message you or send requests. You’ll still both be in this Plan unless one of you leaves. They won’t be told.'),
          okLabel: tr('Block'),
          okKind: BK.dangerSolid,
          icon: 'slash',
          tone: PillTone.bad,
          onConfirm: () async {
            await SafetyApi.block(member.user.id);
            toast(tr('Blocked'));
          },
        );

    Future<void> confirmRemove(PlanMember member) => showConfirm(
          context,
          title: tr('Remove from Plan?'),
          body: tr('They’ll leave the Plan and its group, and be told privately. They can’t rejoin this Plan.'),
          okLabel: tr('Remove'),
          okKind: BK.dangerSolid,
          icon: 'user-x',
          tone: PillTone.bad,
          onConfirm: () async {
            if (detail.planId != null) {
              await PlansApi.removeParticipant(detail.planId!, member.user.id);
              await convo.load();
            }
          },
        );

    Future<void> confirmLeave() => showConfirm(
          context,
          title: tr('Leave this Plan?'),
          body: tr('You’ll leave the Plan Group too. Connections you made stay with you.'),
          okLabel: tr('Leave Plan'),
          okKind: BK.dangerSolid,
          icon: 'log-out',
          tone: PillTone.bad,
          onConfirm: () async {
            if (detail.planId != null) {
              await PlansApi.leave(detail.planId!);
              Nav.navigate('/chats');
            }
          },
        );

    void menu() => showActionSheet(context, title: detail.planTitle ?? detail.title, actions: [
          SheetAction(tr('View Plan'), 'calendar', () => Nav.push('/plan/${detail.planId}')),
          SheetAction(detail.muted ? tr('Unmute group') : tr('Mute group'), detail.muted ? 'bell' : 'bell-off', () async {
            await ChatApi.mute(detail.id, !detail.muted);
            convo.setDetail(detail.copyWith({'muted': !detail.muted}));
          }),
          if (owner && detail.planId != null) SheetAction(tr('Post an announcement'), 'volume-2', () => Nav.push('/plan/${detail.planId}/announce')),
          SheetAction(
            tr('Report group'),
            'flag',
            () => openReport(ReportParams(targetType: 'GROUP', targetId: detail.id, title: detail.planTitle ?? detail.title, sub: tr('Plan Group'))),
            danger: true,
            sub: tr('Reports are private'),
          ),
          if (!owner && !detail.archived) SheetAction(tr('Leave Plan'), 'log-out', confirmLeave, danger: true),
        ]);

    void memberMenu(PlanMember member) => showActionSheet(context, title: member.user.displayName, sub: tr(_role[member.role] ?? member.role), actions: [
          SheetAction(tr('View profile'), 'user', () => Nav.push('/user/${member.user.id}')),
          SheetAction(
            tr('Report {v}', {'v': firstName(member.user.displayName)}),
            'flag',
            () => openReport(ReportParams(
              targetType: 'PARTICIPANT',
              targetId: member.user.id,
              title: member.user.displayName,
              sub: tr('Participant in {planTitle}', {'planTitle': detail.planTitle}),
              personId: member.user.id,
              personName: firstName(member.user.displayName),
            )),
            danger: true,
            sub: tr('Reports are private'),
          ),
          SheetAction(tr('Block {v}', {'v': firstName(member.user.displayName)}), 'slash', () => confirmBlock(member), danger: true),
          if (owner && member.role == 'PARTICIPANT')
            SheetAction(tr('Remove from Plan'), 'user-x', () => confirmRemove(member), danger: true, sub: tr('They’re told privately')),
        ]);

    void msgMenu(LocalMessage m) => showActionSheet(context, title: tr('Message from {v}', {'v': m.sender?.displayName ?? ''}), quote: m.text, actions: [
          SheetAction(
            tr('Report message'),
            'flag',
            () => openReport(ReportParams(
              targetType: 'MESSAGE',
              targetId: m.id,
              title: tr('A message from {v}', {'v': m.sender?.displayName}),
              sub: detail.planTitle,
              quote: m.text,
              personId: m.sender?.id,
              personName: firstName(m.sender?.displayName ?? ''),
            )),
            danger: true,
            sub: tr('Reports are private'),
          ),
        ]);

    final List<Widget> body;
    if (tab == 'chat') {
      body = [
        if (messages.isEmpty) Txt(tr('No messages yet. Say hi to the group.'), variant: TV.small, align: TextAlign.center),
        for (final (i, m) in messages.indexed)
          Builder(key: ValueKey(m.key), builder: (context) {
            final showUnread = i == dividerAt;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (showUnread) _unreadDivider(unreadCount),
              if (m.system)
                _systemMessage(m.text, AppColors.muted, vMargin: 0)
              else
                Pressable(
                  onPress: m.failed ? () => convo.send(m.text, m) : (!m.mine && !m.removed ? () => msgMenu(m) : null),
                  label: '${m.mine ? tr('You') : m.sender?.displayName}: ${m.removed ? tr('Message removed') : m.text}',
                  builder: (_, _, _) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Avatar(name: m.removed ? '?' : (m.sender?.displayName ?? tr('You')), id: m.sender?.id ?? 0, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Txt(
                          '${m.mine ? tr('You') : (m.removed ? tr('Removed') : (m.sender?.displayName ?? ''))} · ${m.failed ? tr('Not sent · tap to retry') : (m.pending ? tr('Sending…') : messageTime(m.createdAt))}',
                          variant: TV.caption,
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.92,
                          alignment: Alignment.centerLeft,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: m.mine ? AppColors.brandPale : AppColors.surface,
                                border: Border.all(color: m.mine ? const Color(0xFFBCD9CC) : AppColors.line),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                m.removed ? tr('This message was removed') : m.text,
                                style: TextStyle(
                                  fontFamily: Fonts.body,
                                  fontSize: 14,
                                  height: 20 / 14,
                                  color: m.removed ? AppColors.inkSoft : AppColors.ink,
                                  fontStyle: m.removed ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
            ]);
          }),
      ];
    } else {
      body = [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < detail.members.length; i++)
              Builder(builder: (context) {
                final mb = detail.members[i];
                final sig = topSignal(mb.user.signals);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null),
                  child: Row(children: [
                    Expanded(
                      child: Pressable(
                        onPress: mb.me ? null : () => Nav.push('/user/${mb.user.id}'),
                        label: mb.me ? tr('You') : mb.user.displayName,
                        builder: (_, _, _) => Row(children: [
                          Avatar(name: mb.user.displayName, photoUrl: mb.user.photoUrl, id: mb.user.id, size: 38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Col(gap: 3, [
                              Txt(mb.me ? tr('You') : mb.user.displayName, variant: TV.bodyStrong),
                              if (sig != null) Pill(sig, icon: 'check', tone: PillTone.ok),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Txt(tr(_role[mb.role] ?? mb.role), variant: TV.caption),
                    if (!mb.me) ...[
                      const SizedBox(width: 8),
                      IconBtn('more-horizontal', label: tr('Options for {displayName}', {'displayName': mb.user.displayName}), onPress: () => memberMenu(mb)),
                    ],
                  ]),
                );
              }),
          ]),
        ),
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconBtn('chevron-left', label: tr('Back'), onPress: goBack),
              const SizedBox(width: 4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Txt(tr('TEMPORARY PLAN GROUP'), variant: TV.kicker),
                  Text(detail.planTitle ?? detail.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.display, fontSize: 17, color: AppColors.ink)),
                  Txt('${tr('{n} participants', {'n': detail.members.length})}${detail.muted ? ' · ${tr('Muted')}' : ''}', variant: TV.caption),
                  if (detail.official)
                    Row(children: [
                      const FIcon('check', size: 10, color: AppColors.brand),
                      const SizedBox(width: 4),
                      Flexible(child: Txt(tr('Official event · Organizer verified'), variant: TV.caption, style: const TextStyle(color: AppColors.brand))),
                    ]),
                ]),
              ),
              const SizedBox(width: 4),
              IconBtn('more-horizontal', label: tr('Group options'), onPress: menu),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const IconTile('calendar', size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Txt(tr('PLAN GROUP'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                  Txt(detail.planLine, variant: TV.bodyStrong, maxLines: 1),
                ]),
              ),
              const SizedBox(width: 10),
              Button(tr('View Plan'), compact: true, kind: BK.secondary, onPress: () => Nav.push('/plan/${detail.planId}')),
            ]),
          ),
          if (detail.archived)
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const FIcon('lock', size: 13, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(child: Txt(detail.archivedReason ?? tr('This Plan Group is archived and read-only.'), variant: TV.small)),
              ]),
            ),
          if (detail.announcement != null)
            Semantics(
              label: tr('Pinned announcement'),
              container: true,
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE0EDF2), borderRadius: BorderRadius.circular(16)),
                child: Col(gap: 4, [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(
                      child: Text(tr('IMPORTANT ANNOUNCEMENT'),
                          style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: Color(0xFF2B5C74))),
                    ),
                    const SizedBox(width: 8),
                    Txt(relativeTime(detail.announcement!.at), variant: TV.caption),
                  ]),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: detail.announcement!.title, style: const TextStyle(fontFamily: Fonts.bodyBold)),
                      TextSpan(text: ' ${detail.announcement!.body}'),
                    ]),
                    style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, height: 19 / 13, color: AppColors.ink),
                  ),
                  Txt('${detail.announcement!.by} ${tr('· Pinned')}', variant: TV.caption),
                ]),
              ),
            ),
          SegmentTabs<String>(
            tabs: [TabSpec('chat', tr('Chat')), TabSpec('people', tr('Participants · {v}', {'v': detail.members.length}))],
            value: tab,
            onChange: (k) {
              setState(() => tab = k);
              if (k == 'chat') scrollToEnd();
            },
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              children: gapped(body, 10),
            ),
          ),
          if (detail.canSend)
            Composer(onSend: (t) => convo.send(t), placeholder: tr('Message the group…'), note: tr('Visible to approved Plan participants only.')),
        ]),
      ),
    );
  }
}
