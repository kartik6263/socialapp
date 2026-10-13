import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/focus_data.dart';
import '../state/toast.dart';
import '../util/format.dart';
import '../util/misc.dart';
import '../util/push.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';

const _sections = ['Today', 'Yesterday', 'This week', 'Earlier'];

const _icons = <String, IconName>{
  'clock': 'clock', 'calendar': 'calendar', 'megaphone': 'volume-2', 'users': 'users', 'close': 'x', 'lock': 'lock', 'spark': 'star', 'shield': 'shield',
  'check': 'check',
};

PillTone _toneFor(AppNotification n) {
  if (n.icon == 'close') return PillTone.bad;
  if (n.icon == 'lock') return PillTone.ink;
  if (n.priority == 'LOW') return PillTone.neutral;
  if (n.priority == 'HIGH') return PillTone.blue;
  if (n.icon == 'clock') return PillTone.lime;
  return PillTone.ok;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with FocusData<NotificationsScreen, List<AppNotification>> {
  String tab = 'ALL';
  PushPermission? permission;
  bool permDismissed = false;

  @override
  Future<List<AppNotification>> load() => NotificationsApi.list();

  @override
  void initState() {
    super.initState();
    getPushPermission().then((p) {
      if (mounted) setState(() => permission = p);
    });
  }

  void _setRead(int id, bool read) {
    setData(data?.map((n) => n.id == id ? n.copyWith({'read': read}) : n).toList());
    final auth = authOf(context);
    NotificationsApi.markRead(id, read).then((_) => auth.refreshUser()).catchError((_) {});
  }

  void _open(AppNotification n) {
    if (!n.read) _setRead(n.id, true);
    openDestination(n.destination);
  }

  Future<void> _markAll() async {
    final auth = authOf(context);
    setData(data?.map((n) => n.copyWith({'read': true})).toList());
    try {
      await NotificationsApi.markAllRead();
    } catch (_) {}
    auth.refreshUser().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final list = data ?? const <AppNotification>[];
    final shown = list.where((n) => tab == 'ALL' || n.category == tab).toList();
    int unreadIn(String c) => list.where((n) => !n.read && (c == 'ALL' || n.category == c)).length;
    final anyUnread = unreadIn('ALL') > 0;

    return Screen(padded: false, onRefresh: refresh, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          IconBtn('chevron-left', label: tr('Back'), onPress: goBack),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(tr('USEFUL UPDATES ONLY'), variant: TV.kicker),
              Txt(tr('Notifications'), variant: TV.title, style: const TextStyle(fontSize: 22)),
            ]),
          ),
          Button(tr('Mark all read'), kind: BK.text, compact: true, disabled: !anyUnread, onPress: _markAll),
          IconBtn('settings', label: tr('Notification settings'), onPress: () => Nav.push('/notifications/settings')),
        ]),
      ),
      SegmentTabs<String>(
        tabs: [
          TabSpec('ALL', tr('All')),
          TabSpec('PLANS', tr('Plans'), unreadIn('PLANS')),
          TabSpec('PEOPLE', tr('People'), unreadIn('PEOPLE')),
          TabSpec('SAFETY', tr('Safety'), unreadIn('SAFETY')),
        ],
        value: tab,
        onChange: (k) => setState(() => tab = k),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if ((error?.isNetwork ?? false) && data != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Banner(
                icon: 'wifi-off',
                tone: PillTone.neutral,
                title: tr('You’re offline'),
                body: tr('We’ll show new notifications when your connection returns. Showing saved updates.'),
                action: tr('Retry'),
                onAction: refresh,
              ),
            ),
          if (permission == 'undetermined' && !permDismissed)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconTile('bell'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Txt(tr('Stay updated on your Plans'), variant: TV.bodyStrong),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Txt(tr('Get a push when a Plan changes, someone messages or connects with you, or your group posts an update.'), variant: TV.small),
                      ),
                    ]),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Expanded(
                      child: Button(tr('Enable notifications'), compact: true, onPress: () async {
                        final p = await enablePush();
                        if (mounted) setState(() => permission = p);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Button(tr('Not now'), kind: BK.secondary, compact: true, onPress: () => setState(() => permDismissed = true)),
                  ]),
                ),
              ]),
            ),
          if (loading)
            const Skeleton(rows: 4)
          else if (error != null && data == null)
            ErrorBlock.of(error!, onRetry: refresh, title: tr('Couldn’t load notifications'))
          else if (shown.isEmpty)
            StateBlock(icon: 'bell', title: tr('You’re all caught up'), body: tr('Important updates about your Plans, connections and conversations will appear here.'))
          else ...[
            if (!anyUnread) Banner(icon: 'check', title: tr('You’re all caught up'), body: tr('New updates about your Plans will appear here.')),
            for (final sec in _sections)
              if (shown.any((n) => sectionFor(n.createdAt) == sec))
                Semantics(
                  label: tr(sec),
                  container: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Txt(tr(sec).toUpperCase(), variant: TV.section),
                    Col(gap: 8, [
                      for (final n in shown.where((n) => sectionFor(n.createdAt) == sec))
                        _NotificationItem(
                          key: ValueKey(n.id),
                          raw: n,
                          onOpen: () => _open(n),
                          onMore: () => showActionSheet(context, title: n.title, actions: [
                            SheetAction(n.read ? tr('Mark as unread') : tr('Mark as read'), 'check', () => _setRead(n.id, !n.read)),
                            SheetAction(tr('Notification settings'), 'settings', () => Nav.push('/notifications/settings')),
                          ]),
                        ),
                    ]),
                  ]),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const FIcon('check', size: 13, color: AppColors.brand),
                const SizedBox(width: 6),
                Flexible(child: Txt(tr('That’s everything. Notifications do not become a feed.'), variant: TV.small)),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification raw;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  const _NotificationItem({super.key, required this.raw, required this.onOpen, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final lang = useLanguage(context);
    // Notification text is stored in English; show it in the app language (names, titles and quotes pass through).
    final title = translateServer(raw.title, lang);
    final body = raw.body != null ? translateServer(raw.body, lang) : null;
    final ctx = raw.context != null ? translateServer(raw.context, lang) : null;
    final cta = translateServer(raw.cta, lang);
    final pill = raw.priority == 'HIGH' ? tr('Important') : (raw.priority == 'LOW' ? tr('Suggestion') : null);
    final isSuggestion = raw.priority == 'LOW';

    return Pressable(
      onPress: onOpen,
      label: '${raw.read ? '' : tr('New. ')}$title. ${body ?? raw.quote ?? ''}. $cta',
      focusRadius: BorderRadius.circular(18),
      builder: (_, pressed, _) => Opacity(
        opacity: pressed ? 0.92 : 1,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: raw.read ? AppColors.surface : const Color(0xFFFBFDFB),
            border: Border.all(color: raw.read ? AppColors.line : const Color(0xFFBCD9CC)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (raw.actor != null)
              Avatar(name: raw.actor!.displayName, photoUrl: raw.actor!.photoUrl, id: raw.actor!.id, size: 40)
            else
              IconTile(_icons[raw.icon] ?? 'bell', tone: _toneFor(raw), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Col(gap: 4, [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
                  if (pill != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: isSuggestion ? AppColors.divider : const Color(0xFFE0EDF2), borderRadius: BorderRadius.circular(999)),
                      child: Text(pill,
                          style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, color: isSuggestion ? AppColors.inkSoft : const Color(0xFF2B5C74))),
                    ),
                  Txt(relativeTime(raw.createdAt), variant: TV.caption),
                  if (!raw.read)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(tr('New'), style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, color: AppColors.brand)),
                    ]),
                ]),
                Text(title, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 14, height: 19 / 14, color: AppColors.ink)),
                if (body != null && body.isNotEmpty) Txt(body, variant: TV.small),
                if (raw.quote != null && raw.quote!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
                    child: Text(raw.quote!, style: const TextStyle(fontFamily: Fonts.body, fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.inkSoft)),
                  ),
                if (raw.diff.isNotEmpty) Diff(raw.diff),
                if (ctx != null && ctx.isNotEmpty)
                  Row(children: [
                    const FIcon('link', size: 10, color: AppColors.inkSoft),
                    const SizedBox(width: 4),
                    Expanded(child: Txt(ctx, variant: TV.caption)),
                  ]),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Flexible(child: Text(cta, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: AppColors.brand))),
                    const SizedBox(width: 4),
                    const FIcon('arrow-right', size: 12, color: AppColors.brand),
                  ]),
                ),
              ]),
            ),
            IconBtn('more-horizontal', label: tr('More options for {title}', {'title': title}), onPress: onMore),
          ]),
        ),
      ),
    );
  }
}

// ---------- Notification settings ----------

const _prefSections = <(String, List<(String, String, String?)>, String?, bool)>[
  ('Messages', [('directMessages', 'Direct messages', 'Repeat messages are grouped.'), ('groupMessages', 'Group messages', 'Grouped per Plan Group.')], null, false),
  ('Connections', [('connectionRequests', 'Connection requests', null), ('acceptedRequests', 'Accepted requests', null)], null, false),
  (
    'Plans',
    [
      ('planUpdates', 'Plan updates', 'Time, place or capacity changes.'),
      ('planReminders', 'Plan reminders', null),
      ('participantUpdates', 'Participant updates', 'Joins and leaves on Plans you created.'),
      ('cancellations', 'Cancellation & completion', null),
    ],
    null,
    true,
  ),
  ('Groups', [('announcements', 'Important announcements', 'From the Plan creator.')], 'Group messages are under Messages.', false),
  ('Discovery', [('suggestions', 'Relevant Plan suggestions', 'At most one a week. Never promotional.')], null, false),
];

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with FocusData<NotificationSettingsScreen, NotificationPrefs> {
  PushPermission? permission;
  String? saveError;

  @override
  Future<NotificationPrefs> load() => NotificationsApi.prefs();

  @override
  void initState() {
    super.initState();
    getPushPermission().then((p) {
      if (mounted) setState(() => permission = p);
    });
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    final d = data;
    if (d == null) return;
    setState(() {
      data = d.copyWith(patch);
      saveError = null;
    });
    try {
      final saved = await NotificationsApi.updatePrefs(patch);
      if (mounted) setData(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        data = d;
        saveError = e is ApiError && e.isNetwork
            ? tr('You’re offline. Reconnect to save this change. Nothing was changed.')
            : tr('Your setting wasn’t changed. Try again.');
      });
    }
  }

  Widget _card(String title, String sub) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDFE6E1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Txt(title, variant: TV.bodyStrong), Txt(sub, variant: TV.small)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    final d = data;
    return Screen(children: [
      Header(kicker: tr('SETTINGS'), title: tr('Notifications')),
      if (saveError != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Banner(icon: 'refresh-cw', tone: PillTone.bad, title: tr('We couldn’t save this change'), body: saveError)),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card(tr('In-app'), tr('Always listed in Notifications.')),
        const SizedBox(width: 8),
        _card(tr('Push'), tr('Outside the app, for the categories you choose.')),
      ]),
      if (permission == 'denied' || permission == 'undetermined')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Banner(
            icon: 'bell-off',
            tone: PillTone.warn,
            title: tr('Push is off on this device'),
            body: tr('In-app notifications still appear.'),
            action: tr('Enable'),
            onAction: () async {
              final p = await enablePush();
              if (mounted) setState(() => permission = p);
              if (p != 'granted') toast(tr('Turn on notifications for Plans in your device settings.'));
            },
          ),
        ),
      if (loading)
        const Skeleton(rows: 5)
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else if (d != null) ...[
        Group(margin: const EdgeInsets.only(top: 12), [
          ToggleRow(
            first: true,
            label: tr('Push notifications'),
            sub: d.push ? tr('On for the categories below') : tr('Off — in-app only'),
            value: d.push,
            onChange: (v) => _update({'push': v}),
          ),
        ]),
        for (final (title, rows, note, plans) in _prefSections) ...[
          SectionTitle(tr(title)),
          Group([
            for (var i = 0; i < rows.length; i++)
              ToggleRow(
                first: i == 0,
                label: tr(rows[i].$2),
                sub: rows[i].$3 != null ? tr(rows[i].$3!) : null,
                value: d[rows[i].$1],
                onChange: (v) => _update({rows[i].$1: v}),
              ),
            if (plans)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF1EE)))),
                child: Col(gap: 8, [
                  Txt(tr('Remind me'), variant: TV.bodyStrong),
                  Txt(tr('At most two reminders per Plan.'), variant: TV.small),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(tr('Day before'), selected: d.remindDayBefore, onPress: () => _update({'remindDayBefore': !d.remindDayBefore})),
                    Chip(tr('1 hour before'), selected: d.remindHourBefore, onPress: () => _update({'remindHourBefore': !d.remindHourBefore})),
                  ]),
                ]),
              ),
          ]),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Txt(tr(note), variant: TV.small)),
        ],
        SectionTitle(tr('Safety & security')),
        Group([
          ListRow(first: true, label: tr('Security alerts'), sub: tr('Sign-ins and account changes.'), right: Pill(tr('Always on'), icon: 'lock')),
          ListRow(label: tr('Safety & account updates'), sub: tr('Report outcomes, restrictions.'), right: Pill(tr('Always on'), icon: 'lock')),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Txt(tr('These always reach you in-app and by push, so you never miss a change to your account.'), variant: TV.small),
        ),
      ],
    ]);
  }
}
