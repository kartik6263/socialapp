import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/focus_data.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import '../widgets/parts.dart';
import '../widgets/trust_signals.dart';
import '../widgets/ui.dart';

/// One per tab: bumped when that tab is shown again, so its data refreshes (useFocusEffect).
final tabTicks = List.generate(4, (_) => ValueNotifier<int>(0));

const _items = [
  ('Discover', 'home'),
  ('My plans', 'calendar'),
  ('Chats', 'message-circle'),
  ('Profile', 'user'),
];

class TabsShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  const TabsShell({super.key, required this.shell});

  @override
  State<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<TabsShell> with RouteAware {
  ModalRoute<void>? _route;

  void _bump(int i) => WidgetsBinding.instance.addPostFrameCallback((_) => tabTicks[i].value++);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = r;
      if (r != null) routeObserver.subscribe(this, r);
    }
  }

  @override
  void didUpdateWidget(covariant TabsShell old) {
    super.didUpdateWidget(old);
    if (old.shell.currentIndex != widget.shell.currentIndex) _bump(widget.shell.currentIndex);
  }

  @override
  void didPopNext() => _bump(widget.shell.currentIndex);

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final user = context.watch<AuthState>().user;
    final unreadChats = user?.unreadConversations ?? 0;
    final insets = MediaQuery.paddingOf(context);
    final index = widget.shell.currentIndex;

    Widget tab(int i) {
      final badge = i == 2 && unreadChats > 0 ? (unreadChats > 9 ? '9+' : '$unreadChats') : null;
      return Expanded(
        child: _TabItem(
          label: tr(_items[i].$1),
          icon: _items[i].$2,
          focused: index == i,
          badge: badge,
          onPress: () => widget.shell.goBranch(i, initialLocation: i == index),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: widget.shell,
      bottomNavigationBar: Container(
        // Matches the bottom of the screen backdrop so the floating bar doesn't sit on a visible strip.
        color: Aurora.base[2],
        padding: EdgeInsets.only(left: 12, right: 12, top: 6, bottom: insets.bottom > 10 ? insets.bottom : 10),
        child: Glass(
          blur: true,
          radius: 28,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            tab(0),
            tab(1),
            Expanded(
              child: Pressable(
                onPress: () => Nav.push('/plan/new'),
                scale: 0.92,
                label: tr('Create a Plan'),
                focusRadius: BorderRadius.circular(18),
                builder: (_, _, _) => SizedBox(
                  height: 52,
                  child: Center(
                    child: Transform.rotate(
                      angle: -4 * 3.1415926535 / 180,
                      child: Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: brandGradient),
                          boxShadow: const [BoxShadow(color: Color.fromRGBO(12, 79, 64, 0.35), blurRadius: 12, offset: Offset(0, 6))],
                        ),
                        child: const FIcon('plus', size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            tab(2),
            tab(3),
          ]),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconName icon;
  final bool focused;
  final String? badge;
  final VoidCallback onPress;
  const _TabItem({required this.label, required this.icon, required this.focused, required this.badge, required this.onPress});

  @override
  Widget build(BuildContext context) {
    final still = reducedMotion(context);
    return Pressable(
      onPress: onPress,
      selected: focused,
      label: badge != null ? tr('{label}, {badge} unread conversations', {'label': label, 'badge': badge}) : label,
      focusRadius: BorderRadius.circular(16),
      builder: (_, _, _) => SizedBox(
        height: 52,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 52,
            height: 30,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              // The active tab gets a soft pill of light behind its icon.
              AnimatedScale(
                scale: focused ? 1 : 0.6,
                duration: still ? Duration.zero : const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: focused ? 1 : 0,
                  duration: still ? Duration.zero : const Duration(milliseconds: 200),
                  child: Container(decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(15))),
                ),
              ),
              FIcon(icon, size: 20, color: focused ? AppColors.brandDark : AppColors.inkSoft),
              if (badge != null)
                Positioned(
                  right: 6,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.badge,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: Fonts.bodyBold, height: 1)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, color: focused ? AppColors.brandDark : AppColors.inkSoft)),
        ]),
      ),
    );
  }
}

// ---------- Discover ----------

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with FocusData<DiscoverScreen, DiscoverResponse> {
  String filter = 'all';

  @override
  Future<DiscoverResponse> load() {
    authOf(context).refreshUser().catchError((_) {}); // keeps bell / chat badges fresh
    return DiscoverApi.home(filter);
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final unread = me.unreadNotifications;
    final badge = unread > 9 ? '9+' : (unread > 0 ? '$unread' : null);
    final d = data;

    return Screen(
      padded: false,
      onRefresh: refresh,
      children: [
        SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Logo(),
              const Spacer(),
              IconBtn('bell',
                  filled: true,
                  label: badge != null ? tr('Notifications, {badge} unread', {'badge': badge}) : tr('Notifications'),
                  badge: badge,
                  onPress: () => Nav.push('/notifications')),
              const SizedBox(width: 8),
              Pressable(
                onPress: () => Nav.push('/me'),
                label: tr('Your profile'),
                focusRadius: BorderRadius.circular(20),
                builder: (_, _, _) => Avatar(name: me.displayName, photoUrl: me.photoUrl, id: me.id, size: 40, tone: AvatarTone.violet),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (me.accountStatus == 'RESTRICTED')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => Nav.push('/settings/restricted'),
                  child: Banner(icon: 'lock', tone: PillTone.warn, title: tr('Some features are limited on your account'), body: tr('See what’s affected')),
                ),
              ),
            Txt(tr('PLANS FIRST · PEOPLE WITH CONTEXT'), variant: TV.kicker),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Headline(text: tr('Discover who else is '), accent: tr('doing it.'))),
            Txt(tr('Relevant plans and people around your selected area, schedule and interests.')),
            Pressable(
              onPress: () => Nav.push('/search'),
              label: tr('Search plans, people, destinations'),
              focusRadius: BorderRadius.circular(18),
              builder: (_, _, _) => Container(
                height: 52,
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: GlassTokens.fillStrong,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GlassTokens.border),
                  boxShadow: glassShadow == null ? null : const [BoxShadow(color: Color.fromRGBO(12, 79, 64, 0.07), blurRadius: 24, offset: Offset(0, 10))],
                ),
                child: Row(children: [
                  const FIcon('search', size: 18, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr('Search plans, people, destinations'), style: const TextStyle(fontFamily: Fonts.body, fontSize: 14, color: AppColors.inkSoft))),
                ]),
              ),
            ),
            _sectionHead(tr('NEAR YOUR SELECTED AREA'), tr('Nearby plans')),
            FilterPills<String>(
              options: [TabSpec('all', tr('All plans')), TabSpec('official', tr('Official events'))],
              value: filter,
              onChange: (k) {
                setState(() => filter = k);
                reload();
              },
            ),
            if (loading)
              const Skeleton()
            else if (error != null && d == null)
              ErrorBlock.of(error!, onRetry: refresh)
            else if (d != null) ...[
              if (d.organizerNearby != null && filter == 'official')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Card(
                    onPress: () => Nav.push('/organizer/${d.organizerNearby!.id}'),
                    child: Row(children: [
                      Avatar(name: d.organizerNearby!.name, id: d.organizerNearby!.id, size: 44, tone: AvatarTone.mint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Txt(tr('ORGANIZER NEAR YOU'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                          Txt(d.organizerNearby!.name, variant: TV.bodyStrong),
                          Txt(
                            '${d.organizerNearby!.signals.contains('ORGANIZER') ? tr('Organizer verified · ') : ''}${d.organizerNearby!.upcomingCount} ${tr('upcoming events')}',
                            variant: TV.small,
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      const FIcon('arrow-right', size: 16, color: AppColors.brand),
                    ]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: d.plans.isNotEmpty
                    // Cards settle in one after another on arrival, so the eye follows the list.
                    ? Col(gap: 14, [
                        for (var i = 0; i < d.plans.length; i++)
                          Appear(
                            key: ValueKey('plan-${d.plans[i].id}'),
                            delay: Duration(milliseconds: (i < 5 ? i : 5) * 70),
                            child: PlanCard(plan: d.plans[i], onPress: () => Nav.push('/plan/${d.plans[i].id}')),
                          ),
                      ])
                    : StateBlock(
                        icon: 'calendar',
                        title: tr('Nothing nearby yet'),
                        body: tr('Create a Plan and let people around you discover it.'),
                        actions: [StateAction(tr('Create a Plan'), () => Nav.push('/plan/new'))],
                      ),
              ),
              _sectionHead(tr('PEOPLE WITH A REAL-WORLD REASON'), tr('People around your plans')),
              if (d.hiddenFromPeople)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => Nav.push('/settings/discover'),
                    child: Banner(
                      icon: 'eye-off',
                      tone: PillTone.neutral,
                      title: tr('You’re hidden from People discovery. You can still see others.'),
                      action: tr('Change'),
                      onAction: () => Nav.push('/settings/discover'),
                    ),
                  ),
                ),
              d.people.isNotEmpty
                  ? Col(gap: 12, [
                      for (var i = 0; i < d.people.length; i++)
                        Appear(key: ValueKey('person-${d.people[i].user.id}'), delay: Duration(milliseconds: (i < 5 ? i : 5) * 70), child: _PersonTile(d.people[i])),
                    ])
                  : StateBlock(icon: 'users', title: tr('No matching people yet'), body: tr('Join or create a Plan — people doing the same thing will appear here.')),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const FIcon('check', size: 13, color: AppColors.brand),
                  const SizedBox(width: 6),
                  Flexible(child: Txt(tr('You’re up to date. Discovery is intentionally finite.'), variant: TV.small)),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _sectionHead(String kicker, String title) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Txt(kicker, variant: TV.kicker),
          const SizedBox(height: 4),
          Txt(title, variant: TV.heading, style: const TextStyle(fontSize: 20)),
        ]),
      );
}

class _PersonTile extends StatelessWidget {
  final PersonCard person;
  const _PersonTile(this.person);

  @override
  Widget build(BuildContext context) {
    final user = person.user;
    return Card(
      child: Col(gap: 9, [
        Row(children: [
          UserAvatar(user, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(user.displayName, variant: TV.bodyStrong),
              if (user.area != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    const FIcon('map-pin', size: 11, color: AppColors.inkSoft),
                    const SizedBox(width: 4),
                    Flexible(child: Txt('${user.area} ${tr('· approximate')}', variant: TV.caption)),
                  ]),
                ),
            ]),
          ),
        ]),
        TrustSignals(signals: user.signals, name: user.displayName.split(' ').first, unavailable: user.signalsUnavailable, compact: true),
        if (person.bio != null && person.bio!.isNotEmpty) Txt(person.bio, variant: TV.small, maxLines: 2),
        Start(Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const FIcon('star', size: 11, color: AppColors.ink),
            const SizedBox(width: 5),
            Flexible(child: Text(person.context, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: AppColors.ink))),
          ]),
        )),
        if (person.sharedInterests.isNotEmpty)
          Txt.rich(trRich('Shared interests: {list}', {'list': bold(person.sharedInterests.join(' · '))}), variant: TV.small),
        Start(Button(
          tr('View profile'),
          kind: BK.secondary,
          compact: true,
          iconRight: 'arrow-right',
          onPress: () => Nav.push('/user/${user.id}'),
          a11yLabel: tr('View {displayName} profile', {'displayName': user.displayName}),
        )),
      ]),
    );
  }
}

// ---------- My plans ----------

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});
  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> with FocusData<MyPlansScreen, MyPlans> {
  @override
  Future<MyPlans> load() => PlansApi.mine();

  Widget? _section(String title, List<PlanSummary> list) {
    if (list.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title),
      Group([for (var i = 0; i < list.length; i++) PlanRow(plan: list[i], first: i == 0, onPress: () => Nav.push('/plan/${list[i].id}'))]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final d = data;
    final empty = d != null && d.upcoming.isEmpty && d.hosting.isEmpty && d.drafts.isEmpty && d.past.isEmpty;
    return Screen(onRefresh: refresh, children: [
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Txt(tr('YOUR CALENDAR'), variant: TV.kicker),
          const SizedBox(height: 8),
          Headline(text: tr('My '), accent: tr('plans.'), size: TV.title),
        ]),
      ),
      if (loading)
        const Skeleton()
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else if (empty)
        StateBlock(
          icon: 'calendar',
          title: tr('No plans yet'),
          body: tr('Start a Plan for something you want to do, or join one nearby.'),
          actions: [
            StateAction(tr('Create a Plan'), () => Nav.push('/plan/new')),
            StateAction(tr('Discover plans'), () => Nav.navigate('/'), BK.secondary),
          ],
        )
      else if (d != null) ...[
        ?_section(tr('Hosting'), d.hosting),
        ?_section(tr('Joined'), d.upcoming),
        ?_section(tr('Drafts'), d.drafts),
        ?_section(tr('Past'), d.past),
      ],
    ]);
  }
}

// ---------- Chats ----------

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> with FocusData<ChatsScreen, List<ConversationSummary>> {
  @override
  Future<List<ConversationSummary>> load() => ChatApi.list();

  void _open(ConversationSummary c) => Nav.push(c.type == 'GROUP' ? '/group/${c.id}' : '/chat/${c.id}');

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final d = data;
    final groups = d?.where((c) => c.type == 'GROUP').toList() ?? [];
    final direct = d?.where((c) => c.type == 'DIRECT').toList() ?? [];
    return Screen(onRefresh: refresh, children: [
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Txt(tr('CONVERSATIONS WITH CONTEXT'), variant: TV.kicker),
          const SizedBox(height: 8),
          Headline(text: tr('Chats'), size: TV.title),
        ]),
      ),
      if (loading)
        const Skeleton()
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else if (d == null || d.isEmpty)
        StateBlock(
          icon: 'message-circle',
          title: tr('No conversations yet'),
          body: tr('Chats open when someone accepts your connection, or when you join a Plan with a group.'),
          actions: [StateAction(tr('Discover plans'), () => Nav.navigate('/'))],
        )
      else ...[
        if (groups.isNotEmpty) ...[
          SectionTitle(tr('Plan groups')),
          Group([for (var i = 0; i < groups.length; i++) _ChatRow(c: groups[i], first: i == 0, onPress: () => _open(groups[i]))]),
        ],
        if (direct.isNotEmpty) ...[
          SectionTitle(tr('Direct messages')),
          Group([for (var i = 0; i < direct.length; i++) _ChatRow(c: direct[i], first: i == 0, onPress: () => _open(direct[i]))]),
        ],
        Padding(padding: const EdgeInsets.only(top: 20), child: Txt(tr('Phone numbers are never shared in chats.'), variant: TV.small, align: TextAlign.center)),
      ],
    ]);
  }
}

class _ChatRow extends StatelessWidget {
  final ConversationSummary c;
  final bool first;
  final VoidCallback onPress;
  const _ChatRow({required this.c, required this.first, required this.onPress});

  @override
  Widget build(BuildContext context) {
    final lm = c.lastMessage;
    final String preview;
    if (lm != null) {
      if (lm.removed) {
        preview = tr('Message removed');
      } else {
        final prefix = c.type == 'GROUP' && lm.sender != null && !lm.mine ? '${lm.sender!.displayName.split(' ').first}: ' : (lm.mine ? 'You: ' : '');
        preview = '$prefix${lm.text}';
      }
    } else {
      preview = c.context ?? tr('Say hello');
    }
    return Pressable(
      onPress: onPress,
      label: '${c.title}${c.unread > 0 ? tr(', {unread} unread', {'unread': c.unread}) : ''}',
      focusRadius: BorderRadius.zero,
      builder: (_, pressed, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: pressed ? AppColors.paper : null, border: first ? null : const Border(top: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          if (c.type == 'GROUP')
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(14)),
              child: const FIcon('users', size: 18, color: AppColors.brand),
            )
          else
            Avatar(name: c.otherUser?.displayName ?? c.title, photoUrl: c.otherUser?.photoUrl, id: c.otherUser?.id ?? c.id, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Col(gap: 2, [
              Row(children: [
                Flexible(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 14, color: AppColors.ink))),
                if (c.muted) ...[const SizedBox(width: 6), const FIcon('bell-off', size: 12, color: AppColors.inkSoft)],
                if (lm != null) ...[const Spacer(), const SizedBox(width: 6), Txt(relativeTime(lm.createdAt), variant: TV.caption)] else const Spacer(),
              ]),
              if (c.context != null)
                Row(children: [
                  const FIcon('link', size: 10, color: AppColors.brand),
                  const SizedBox(width: 4),
                  Expanded(child: Txt(c.context, variant: TV.caption, style: const TextStyle(color: AppColors.brand), maxLines: 1)),
                ]),
              Row(children: [
                Expanded(
                  child: Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: c.unread > 0 ? Fonts.bodySemi : Fonts.body, fontSize: 13, color: c.unread > 0 ? AppColors.ink : AppColors.inkSoft)),
                ),
                if (c.unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(10)),
                    child: Text(c.unread > 9 ? '9+' : '${c.unread}', style: const TextStyle(color: Colors.white, fontFamily: Fonts.bodyBold, fontSize: 10)),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------- My profile ----------

/// "Your profile" (prototype w20.isMe): how others see you, completeness, edit + settings.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> with FocusData<MyProfileScreen, bool> {
  @override
  Future<bool> load() async {
    await authOf(context).refreshUser();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final p = me.privacy;
    final orgVerified = me.organizer?.status == 'VERIFIED';
    final areaText = p.areaLevel == 'CITY' ? (me.city ?? me.area) : '${me.area}${me.city != null ? ', ${me.city}' : ''}';

    return Screen(onRefresh: refresh, children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Txt(tr('Your profile'), variant: TV.bodyStrong, style: const TextStyle(fontSize: 15)),
          IconBtn('settings', label: tr('Settings'), onPress: () => Nav.push('/settings')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Avatar(name: me.displayName, photoUrl: me.photoUrl, id: me.id, size: 84, tone: AvatarTone.violet),
          const SizedBox(height: 12),
          Txt(p.showIntent && me.intents.isNotEmpty ? me.intents.take(2).map(intentLabel).join(' · ').toUpperCase() : tr('INTENT HIDDEN'), variant: TV.kicker),
          const SizedBox(height: 4),
          Txt('${me.displayName}${p.showAge && me.ageRange != null ? ', ${me.ageRange}' : ''}', variant: TV.title, align: TextAlign.center),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const FIcon('map-pin', size: 12, color: AppColors.inkSoft),
              const SizedBox(width: 4),
              Flexible(child: Txt(p.showArea ? tr('{v} · approximate', {'v': areaText}) : tr('Location hidden'), variant: TV.small)),
            ]),
          ),
          TrustSignals(signals: me.signals, name: 'You'),
        ]),
      ),
      if (me.organizer != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FilterPills<String>(
            options: [TabSpec('personal', tr('Personal profile')), TabSpec('org', tr('Organizer profile'))],
            value: 'personal',
            onChange: (k) {
              if (k == 'org') Nav.push('/organizer/${me.organizer!.id}');
            },
          ),
        ),
      if (me.signals.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Banner(
            icon: 'shield',
            tone: PillTone.neutral,
            title: tr('No verification completed yet'),
            body: tr('Complete available verification steps to add trust signals to your profile.'),
            action: tr('Verify'),
            onAction: () => Nav.push('/verify'),
          ),
        ),
      if (me.completeness.percent < 100)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
          child: Col(gap: 8, [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Txt(tr('Profile {percent}% complete', {'percent': me.completeness.percent}), variant: TV.bodyStrong)),
              Txt(tr('{done} of {total}', {'done': me.completeness.done, 'total': me.completeness.total}), variant: TV.caption),
            ]),
            Semantics(
              value: '${me.completeness.percent}%',
              child: Container(
                height: 8,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(4)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (me.completeness.percent.clamp(0, 100)) / 100,
                  child: Container(decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(4))),
                ),
              ),
            ),
            Txt('${me.completeness.hint ?? ''} ${tr('Completeness helps introductions — it isn’t a trust or safety measure.')}', variant: TV.small),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Expanded(child: Button(tr('Edit profile'), icon: 'edit-2', kind: BK.secondary, onPress: () => Nav.push('/edit-profile'))),
          const SizedBox(width: 8),
          Expanded(child: Button(tr('Settings'), kind: BK.secondary, onPress: () => Nav.push('/settings'))),
        ]),
      ),
      if (me.organizer == null)
        Padding(padding: const EdgeInsets.only(top: 6), child: Button(tr('Become an organizer'), kind: BK.text, icon: 'users', onPress: () => Nav.push('/organizer/setup')))
      else if (!orgVerified)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Button(tr('Organizer verification status'), kind: BK.text, icon: 'clock', onPress: () => Nav.push('/verify/organizer')),
        ),
      SectionTitle(tr('About')),
      Txt((me.bio != null && me.bio!.isNotEmpty) ? me.bio : tr('Add a short bio so people know what you’re into.')),
      Padding(padding: const EdgeInsets.only(top: 12), child: ChipWrap(me.interests.map((i) => Chip(i)).toList())),
    ]);
  }
}
