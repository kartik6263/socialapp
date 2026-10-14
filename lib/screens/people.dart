import 'dart:async';

import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../api/client.dart' show appVersionString;
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/focus_data.dart';
import '../state/toast.dart';
import '../util/format.dart';
import '../util/misc.dart';
import '../widgets/parts.dart';
import '../widgets/sheet.dart';
import '../widgets/trust_signals.dart';
import '../widgets/ui.dart';

// ---------- Connection request ----------

class ConnectionRequestScreen extends StatefulWidget {
  final int id;
  const ConnectionRequestScreen({super.key, required this.id});
  @override
  State<ConnectionRequestScreen> createState() => _ConnectionRequestScreenState();
}

class _ConnectionRequestScreenState extends State<ConnectionRequestScreen> with FocusData<ConnectionRequestScreen, ConnectionRequest> {
  String? busy;
  String actionError = '';

  @override
  Future<ConnectionRequest> load() => ConnectionsApi.request(widget.id);

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final header = Header(title: tr('Connection request'), center: true);
    if (loading) return Screen(children: [header, const Loading()]);
    final req = data;
    if (req == null) return Screen(children: [header, if (error != null) ErrorBlock.of(error!, onRetry: refresh)]);

    final name = firstName(req.from.displayName);
    Future<void> act(String kind) async {
      setState(() {
        busy = kind;
        actionError = '';
      });
      try {
        setData(kind == 'accept' ? await ConnectionsApi.accept(req.id) : await ConnectionsApi.decline(req.id));
        if (kind == 'accept') AnalyticsApi.track('connection_accepted');
      } catch (e) {
        if (mounted) setState(() => actionError = e is ApiError ? e.message : tr('Something went wrong. Try again.'));
      } finally {
        if (mounted) setState(() => busy = null);
      }
    }

    Future<void> message() async {
      final c = await ChatApi.openDirect(req.from.id);
      Nav.replace('/chat/${c.id}');
    }

    return Screen(children: [
      header,
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 18),
        child: Column(children: [
          UserAvatar(req.from, size: 76),
          if (req.intents.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Txt(intentKicker(req.intents), variant: TV.kicker)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Txt('${req.from.displayName}${req.ageRange != null ? ', ${req.ageRange}' : ''}', variant: TV.title, align: TextAlign.center),
          ),
          if (req.from.area != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const FIcon('map-pin', size: 12, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Txt('${req.from.area} ${tr('· approximate')}', variant: TV.small),
              ]),
            ),
          TrustSignals(signals: req.from.signals, name: name, unavailable: req.from.signalsUnavailable),
        ]),
      ),
      Col(gap: 10, [
        if (req.sharedPlan != null) SharedPlanCard(plan: req.sharedPlan!, onPress: () => Nav.push('/plan/${req.sharedPlan!.id}')),
        if (req.sharedInterests.isNotEmpty) ContextRow(icon: 'star', label: tr('SHARED INTERESTS'), value: req.sharedInterests.join(' · ')),
        Button(tr('What do these signals mean? You decide — we don’t recommend.'),
            kind: BK.text, icon: 'shield', compact: true, onPress: () => showSignalExplainer(context, const ExplainAbout())),
        if (req.note != null && req.note!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Txt(tr('{name}’s note · {when}', {'name': name, 'when': relativeTime(req.createdAt)}).toUpperCase(),
                  variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
              Padding(padding: const EdgeInsets.only(top: 6), child: Txt('“${req.note}”', style: const TextStyle(color: AppColors.ink))),
            ]),
          ),
      ]),
      if (actionError.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Banner(icon: 'alert-circle', tone: PillTone.bad, title: actionError)),
      if (req.status == 'PENDING') ...[
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(children: [
            Expanded(child: Button(tr('Decline'), kind: BK.secondary, loading: busy == 'decline', disabled: busy != null, onPress: () => act('decline'))),
            const SizedBox(width: 8),
            Expanded(
              child: Button(busy == 'accept' ? tr('Connecting…') : tr('Accept'), loading: busy == 'accept', disabled: busy != null, onPress: () => act('accept')),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Txt('$name ${tr('won’t be told if you decline.')}', variant: TV.small, align: TextAlign.center)),
        Button(tr('View full profile'), kind: BK.text, iconRight: 'arrow-right', onPress: () => Nav.push('/user/${req.from.id}')),
      ] else if (req.status == 'ACCEPTED')
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Banner(icon: 'check', title: tr('You’re connected'), body: req.sharedPlan != null ? tr('Connected through {title}', {'title': req.sharedPlan!.title}) : null),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Expanded(child: Button(tr('View profile'), kind: BK.secondary, onPress: () => Nav.push('/user/${req.from.id}'))),
                const SizedBox(width: 8),
                Expanded(child: Button(tr('Message'), onPress: message)),
              ]),
            ),
          ]),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Banner(icon: 'info', tone: PillTone.neutral, title: tr('Request declined.'), body: tr('You can still both join the Plan — nothing else changes.')),
        ),
    ]);
  }
}

// ---------- Person profile ----------

class PersonProfileScreen extends StatefulWidget {
  final int id;
  const PersonProfileScreen({super.key, required this.id});
  @override
  State<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

class _PersonProfileScreenState extends State<PersonProfileScreen> with FocusData<PersonProfileScreen, PublicProfile> {
  bool busy = false;

  @override
  Future<PublicProfile> load() async {
    final profile = await UsersApi.get(widget.id);
    AnalyticsApi.track('profile_viewed');
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    final header0 = Header(title: tr('Profile'), center: true);
    if (loading) return Screen(children: [header0, const Loading()]);
    final p = data;
    if (p == null) return Screen(children: [header0, if (error != null) ErrorBlock.of(error!, onRetry: refresh)]);

    if (p.availability != 'AVAILABLE') {
      final (title, body) = switch (p.availability) {
        'RESTRICTED' => (tr('This account currently has limited access'), tr('You can’t message or connect with this account right now.')),
        'SUSPENDED' => (tr('This account is unavailable'), tr('You can’t view this profile or message this person.')),
        _ => (tr('This account is no longer available'), tr('The person deleted their account.')),
      };
      return Screen(children: [
        header0,
        StateBlock(icon: 'user', tone: PillTone.neutral, title: title, body: body, actions: [StateAction(tr('Back'), goBack)]),
      ]);
    }

    Future<void> connect() async {
      setState(() => busy = true);
      try {
        await ConnectionsApi.send(p.id, p.sharedPlan?.id);
        setData(p.copyWith({'connectionStatus': 'PENDING_OUTGOING'}));
        AnalyticsApi.track('connection_sent', {'hasPlan': p.sharedPlan != null});
        toast(tr('Request sent to {firstName}', {'firstName': p.firstName}));
      } catch (e) {
        toast(e is ApiError ? e.message : tr('Couldn’t send the request.'));
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }

    Future<void> message() async {
      try {
        final c = await ChatApi.openDirect(p.id);
        Nav.push('/chat/${c.id}');
      } catch (e) {
        toast(e is ApiError ? e.message : tr('Couldn’t open the conversation.'));
      }
    }

    Future<void> confirmBlock() => showConfirm(
          context,
          title: tr('Block {firstName}?', {'firstName': p.firstName}),
          body: tr('{firstName} won’t be able to message you, send requests or see your Plans. They won’t be told. You can unblock any time in Safety Center.',
              {'firstName': p.firstName}),
          okLabel: tr('Block'),
          okKind: BK.dangerSolid,
          icon: 'slash',
          tone: PillTone.bad,
          onConfirm: () async {
            await SafetyApi.block(p.id);
            setData(p.copyWith({'blockedByMe': true, 'canMessage': false, 'canConnect': false, 'connectionStatus': 'BLOCKED'}));
            toast(tr('{firstName} blocked', {'firstName': p.firstName}));
          },
        );

    Future<void> confirmUnblock() => showConfirm(
          context,
          title: tr('Unblock {firstName}?', {'firstName': p.firstName}),
          body: tr('They’ll be able to see your Plans and send requests again, based on your privacy settings. They won’t be told.'),
          okLabel: tr('Unblock'),
          icon: 'unlock',
          onConfirm: () async {
            await SafetyApi.unblock(p.id);
            await refresh();
            toast(tr('{firstName} unblocked', {'firstName': p.firstName}));
          },
        );

    void menu() => showActionSheet(context, title: p.displayName, sub: p.sharedPlan != null ? tr('Met through {title}', {'title': p.sharedPlan!.title}) : null, actions: [
          SheetAction(
            tr('Report {firstName}', {'firstName': p.firstName}),
            'flag',
            () => openReport(ReportParams(
              targetType: 'PROFILE',
              targetId: p.id,
              title: tr('{displayName}’s profile', {'displayName': p.displayName}),
              sub: p.sharedPlan?.title,
              personId: p.id,
              personName: p.firstName,
            )),
            sub: tr('Reports are private'),
            danger: true,
          ),
          if (p.blockedByMe)
            SheetAction(tr('Unblock {firstName}', {'firstName': p.firstName}), 'unlock', confirmUnblock)
          else
            SheetAction(tr('Block {firstName}', {'firstName': p.firstName}), 'slash', confirmBlock, sub: tr('They won’t be told'), danger: true),
          if (p.connectionStatus == 'ACCEPTED')
            SheetAction(
              tr('Remove connection'),
              'user-x',
              () => showConfirm(
                context,
                title: tr('Remove connection?'),
                body: tr('You and {firstName} won’t be connected anymore. They won’t be told why.', {'firstName': p.firstName}),
                okLabel: tr('Remove'),
                okKind: BK.dangerSolid,
                icon: 'user-x',
                tone: PillTone.bad,
                onConfirm: () async {
                  await ConnectionsApi.remove(p.id);
                  await refresh();
                },
              ),
            ),
          if (p.connectionStatus == 'PENDING_OUTGOING')
            SheetAction(
              tr('Cancel request'),
              'x',
              () => showConfirm(
                context,
                title: tr('Cancel request?'),
                body: tr('{firstName} won’t see your request anymore.', {'firstName': p.firstName}),
                okLabel: tr('Cancel request'),
                cancelLabel: tr('Keep'),
                icon: 'x',
                onConfirm: () async {
                  if (p.connectionId != null) await ConnectionsApi.cancel(p.connectionId!);
                  await refresh();
                },
              ),
            ),
        ]);

    final statusLabel = switch (p.connectionStatus) {
      'ACCEPTED' => tr('Connected'),
      'PENDING_OUTGOING' => tr('Request sent'),
      'PENDING_INCOMING' => tr('Wants to connect'),
      'BLOCKED' => tr('Blocked'),
      _ => tr('Not connected'),
    };

    return Screen(children: [
      Header(
        title: tr('Profile'),
        center: true,
        right: IconBtn('more-horizontal', label: tr('More options for {firstName}', {'firstName': p.firstName}), onPress: menu),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          UserAvatar(p, size: 84),
          if (p.intents.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Txt(intentKicker(p.intents), variant: TV.kicker)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Txt('${p.displayName}${p.ageRange != null ? ', ${p.ageRange}' : ''}', variant: TV.title, align: TextAlign.center),
          ),
          if (p.area != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const FIcon('map-pin', size: 12, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Txt('${p.area} ${tr('· approximate')}', variant: TV.small),
              ]),
            ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Pill(statusLabel, icon: 'users')),
          TrustSignals(signals: p.signals, name: p.firstName, unavailable: p.signalsUnavailable),
          if (p.signals.isEmpty && !p.signalsUnavailable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Txt(tr('No additional trust signals. That’s common for newer members — the profile works normally.'), variant: TV.small, align: TextAlign.center),
            ),
        ]),
      ),
      if (p.blockedByMe)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const FIcon('lock', size: 20, color: AppColors.inkSoft),
            Padding(padding: const EdgeInsets.only(top: 8), child: Txt(tr('You blocked this person'), variant: TV.bodyStrong)),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Txt(tr('They can’t message you, send connection requests or see your Plans. They weren’t told.'), variant: TV.small, align: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                Expanded(child: Button(tr('Back'), kind: BK.secondary, onPress: goBack)),
                const SizedBox(width: 8),
                Expanded(child: Button(tr('Unblock'), onPress: confirmUnblock)),
              ]),
            ),
          ]),
        )
      else ...[
        if (p.sharedPlan != null || p.sharedInterests.isNotEmpty || p.mutualConnections.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(20)),
            child: Col(gap: 4, [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Txt(tr('YOU HAVE SOMETHING IN COMMON'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
              ),
              if (p.sharedPlan != null) SharedPlanCard(plan: p.sharedPlan!, icon: 'link', onPress: () => Nav.push('/plan/${p.sharedPlan!.id}')),
              if (p.sharedInterests.isNotEmpty) ContextRow(icon: 'star', label: tr('SHARED INTERESTS'), value: p.sharedInterests.join(' · ')),
              if (p.mutualConnections.isNotEmpty) ContextRow(icon: 'users', label: tr('MUTUAL CONNECTIONS'), value: p.mutualConnections.join(', ')),
            ]),
          ),
        SectionTitle(tr('About')),
        Txt((p.bio != null && p.bio!.isNotEmpty) ? p.bio : tr('{firstName} hasn’t added a bio yet.', {'firstName': p.firstName})),
        Padding(padding: const EdgeInsets.only(top: 12), child: ChipWrap(p.interests.map((i) => Chip(i)).toList())),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Col(gap: 8, [
            if (p.connectionStatus == 'PENDING_INCOMING' && p.connectionId != null)
              Button(tr('Respond to request'), onPress: () => Nav.push('/request/${p.connectionId}')),
            if (p.canMessage) Button(tr('Message {firstName}', {'firstName': p.firstName}), icon: 'message-circle', onPress: message),
            if (p.canConnect || p.connectionStatus == 'PENDING_OUTGOING')
              Button(
                p.connectionStatus == 'PENDING_OUTGOING' ? tr('Request sent') : tr('Connect with {firstName}', {'firstName': p.firstName}),
                icon: 'users',
                kind: p.canMessage ? BK.secondary : BK.primary,
                loading: busy,
                disabled: p.connectionStatus == 'PENDING_OUTGOING',
                onPress: connect,
              ),
            if (!p.canMessage && !p.canConnect && p.connectionStatus == 'NONE')
              Banner(
                icon: 'lock',
                tone: PillTone.neutral,
                title: tr('{firstName} isn’t accepting requests right now', {'firstName': p.firstName}),
                body: tr('Their contact settings limit who can connect. You can still join the same Plans.'),
              ),
          ]),
        ),
      ],
    ]);
  }
}

// ---------- Organizer profile ----------

const _orgType = {
  'INDIVIDUAL': 'INDIVIDUAL ORGANIZER',
  'COMMUNITY': 'COMMUNITY ORGANIZER',
  'ORGANIZATION': 'ORGANIZATION',
  'OFFICIAL': 'OFFICIAL EVENT ORGANIZER',
};

class OrganizerProfileScreen extends StatefulWidget {
  final int id;
  const OrganizerProfileScreen({super.key, required this.id});
  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> with FocusData<OrganizerProfileScreen, OrganizerProfile> {
  @override
  Future<OrganizerProfile> load() => OrganizersApi.get(widget.id);

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    if (loading) return Screen(children: [Header(title: tr('Organizer'), center: true), const Loading()]);
    final o = data;
    if (o == null) return Screen(children: [Header(title: tr('Organizer'), center: true), if (error != null) ErrorBlock.of(error!, onRetry: refresh)]);

    final typeLabel = tr(_orgType[o.type] ?? o.type);
    void report() => openReport(ReportParams(targetType: 'ORGANIZER', targetId: o.id, title: o.name, sub: typeLabel.toLowerCase()));

    return Screen(children: [
      Header(
        title: tr('Organizer'),
        center: true,
        right: !o.mine
            ? IconBtn('more-horizontal',
                label: tr('More options for this organizer'),
                onPress: () => showActionSheet(context, title: o.name, actions: [
                      SheetAction(tr('Report this organizer'), 'flag', report, danger: true, sub: tr('Reports are private')),
                    ]))
            : null,
      ),
      if (!o.available)
        StateBlock(icon: 'users', tone: PillTone.neutral, title: tr('This organizer is currently unavailable'), body: tr('Their profile and events can’t be viewed right now.'))
      else ...[
        if (o.mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilterPills<String>(
              options: [TabSpec('personal', tr('Personal profile')), TabSpec('org', tr('Organizer profile'))],
              value: 'org',
              onChange: (k) {
                if (k == 'personal') Nav.navigate('/me');
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Avatar(name: o.name, id: o.id, size: 80, tone: AvatarTone.mint),
            Padding(padding: const EdgeInsets.only(top: 12), child: Txt(typeLabel, variant: TV.kicker)),
            Padding(padding: const EdgeInsets.only(top: 4), child: Txt(o.name, variant: TV.title, align: TextAlign.center)),
            if (o.area != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const FIcon('map-pin', size: 12, color: AppColors.inkSoft),
                  const SizedBox(width: 4),
                  Txt(o.area, variant: TV.small),
                ]),
              ),
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              TrustSignals(signals: o.signals, name: o.name),
              if (o.status != 'VERIFIED') Pill(o.status == 'IN_REVIEW' || o.status == 'SUBMITTED' ? tr('In review') : tr('Not verified'), tone: PillTone.neutral),
            ]),
          ]),
        ),
        if (o.about != null && o.about!.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Txt(o.about)),
        Group(margin: const EdgeInsets.only(top: 8), [
          if (o.website != null) ListRow(first: true, icon: 'globe', label: tr('Website'), value: o.website),
          ListRow(first: o.website == null, icon: 'message-circle', label: tr('Contact'), sub: tr('Through Plan Groups — no private contact shown')),
          ListRow(icon: 'calendar', label: tr('Organizing since'), value: o.since),
        ]),
        SectionTitle(tr('Upcoming')),
        if (o.upcoming.isNotEmpty)
          Group([for (var i = 0; i < o.upcoming.length; i++) PlanRow(plan: o.upcoming[i], first: i == 0, onPress: () => Nav.push('/plan/${o.upcoming[i].id}'))])
        else
          Txt(tr('No upcoming Plans right now.'), variant: TV.small),
        if (o.past.isNotEmpty) ...[
          SectionTitle(tr('Past')),
          Group([for (var i = 0; i < o.past.length; i++) PlanRow(plan: o.past[i], first: i == 0, onPress: () => Nav.push('/plan/${o.past[i].id}'))]),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Txt(
            tr('Organizer verification confirms the organisation. It doesn’t guarantee the quality, safety or outcome of an event. No follower counts or ratings are shown.'),
            variant: TV.small,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: o.mine
              ? Button(tr('Create an event'), icon: 'plus', onPress: () => Nav.push('/plan/new'))
              : Button(tr('Report this organizer'), icon: 'flag', kind: BK.secondary, onPress: report),
        ),
      ],
    ]);
  }
}

// ---------- Organizer setup ----------

const _setupTitles = ['Organizer type', 'About you', 'Your verification', 'Review'];
const _types = [
  ('INDIVIDUAL', 'Individual', 'A person organizing activities'),
  ('COMMUNITY', 'Community', 'You run a recurring community or group'),
  ('ORGANIZATION', 'Organization', 'You represent a registered organization'),
  ('OFFICIAL', 'Official event organizer', 'You’re authorised to represent a specific event'),
];

class OrganizerSetupScreen extends StatefulWidget {
  const OrganizerSetupScreen({super.key});
  @override
  State<OrganizerSetupScreen> createState() => _OrganizerSetupScreenState();
}

class _OrganizerSetupScreenState extends State<OrganizerSetupScreen> {
  int step = 1;
  String? type;
  String name = '';
  String about = '';
  late String area = authOf(context).user?.city ?? '';
  String site = '';
  String email = '';
  String? error;
  bool busy = false;
  bool submitted = false;

  bool get needsSite => type == 'ORGANIZATION' || type == 'OFFICIAL' || type == 'COMMUNITY';
  bool get needsEmail => type == 'ORGANIZATION' || type == 'OFFICIAL';

  Future<void> _next(Me me) async {
    setState(() => error = null);
    if (step == 1 && type == null) return setState(() => error = tr('Choose what you organise.'));
    if (step == 2) {
      if (name.trim().length < 3) return setState(() => error = tr('Add your organizer name.'));
      if (about.trim().length < 20) return setState(() => error = tr('Tell people what you organise (at least 20 characters).'));
      if (needsSite && !RegExp(r'^(https?:\/\/)?[\w-]+(\.[\w-]+)+').hasMatch(site.trim())) return setState(() => error = tr('Add a website or public page.'));
      if (needsEmail && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) return setState(() => error = tr('Add an official contact email.'));
    }
    if (step == 3 && !me.signals.contains('PHONE')) return setState(() => error = tr('Verify your phone first — it’s required for organizers.'));
    if (step < 4) return setState(() => step = step + 1);
    final auth = authOf(context);
    setState(() => busy = true);
    try {
      await OrganizersApi.apply(OrganizerSetup(
        type: type!,
        name: name.trim(),
        about: about.trim(),
        area: area.trim(),
        website: site.trim().isEmpty ? null : site.trim(),
        contactEmail: email.trim().isEmpty ? null : email.trim(),
      ));
      await auth.refreshUser();
      if (mounted) setState(() => submitted = true);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t submit. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _check(bool ok, String label, String sub, [VoidCallback? fix]) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? '✓' : '○', style: TextStyle(fontFamily: Fonts.bodyBold, color: ok ? AppColors.brand : AppColors.inkSoft, fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Txt(label, variant: TV.bodyStrong), Txt(sub, variant: TV.small)])),
          if (!ok && fix != null) ...[const SizedBox(width: 12), Button(tr('Verify'), compact: true, kind: BK.secondary, onPress: fix)],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    if (submitted) {
      return Screen(children: [
        Header(kicker: tr('BECOME AN ORGANIZER'), title: tr('Submitted')),
        StateBlock(
          icon: 'clock',
          tone: PillTone.blue,
          title: tr('Organizer verification submitted'),
          body: tr('We’ll review your details, usually within 1–2 working days, and notify you. You can keep using Plans as normal.'),
          actions: [StateAction(tr('View status'), () => Nav.replace('/verify/organizer')), StateAction(tr('Done'), Nav.back, BK.secondary)],
        ),
      ]);
    }
    final hasIdentity = me.signals.contains('IDENTITY');
    final hasPhone = me.signals.contains('PHONE');
    final typeLabel = _types.where((t) => t.$1 == type).map((t) => t.$2).firstOrNull ?? '';

    return Screen(
      bottom: true,
      footer: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: Button(step == 4 ? tr('Submit for verification') : tr('Continue'), loading: busy, onPress: () => _next(me)),
      ),
      children: [
        Header(kicker: tr('BECOME AN ORGANIZER'), title: tr(_setupTitles[step - 1]), onBack: () => step > 1 ? setState(() => step = step - 1) : Nav.back()),
        StepBars(total: 4, current: step),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Txt(tr('Step {step} of 4', {'step': step}), variant: TV.caption)),
        if (step == 1) ...[
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Txt(tr('Choose what you organise. You keep one account — organizer tools are added to it.'))),
          RadioCards<String>(
            label: tr('Organizer type'),
            options: _types.map((o) => RadioOption(o.$1, tr(o.$2), sub: tr(o.$3))).toList(),
            value: type,
            onChange: (v) => setState(() => type = v),
          ),
        ],
        if (step == 2) ...[
          Field(
            label: type == 'INDIVIDUAL' ? tr('Organizer name') : tr('Organisation name'),
            value: name,
            onChanged: (t) => setState(() => name = t),
            placeholder: tr('Ananya’s Photo Walks'),
          ),
          Field(label: tr('About'), value: about, onChanged: (t) => setState(() => about = t), multiline: true, maxLength: 600, placeholder: tr('What you organise and who it’s for')),
          Field(label: tr('Area'), value: area, onChanged: (t) => setState(() => area = t), placeholder: tr('Bengaluru')),
          if (needsSite)
            Field(
              label: type == 'COMMUNITY' ? tr('Website or public page') : tr('Official website'),
              value: site,
              onChanged: (t) => setState(() => site = t),
              capitalization: TextCapitalization.none,
              keyboardType: TextInputType.url,
              placeholder: tr('https://'),
            ),
          if (needsEmail)
            Field(
              label: tr('Official contact email'),
              value: email,
              onChanged: (t) => setState(() => email = t),
              capitalization: TextCapitalization.none,
              keyboardType: TextInputType.emailAddress,
              placeholder: tr('hello@yourorg.com'),
              hint: tr('Only the domain is checked. This email isn’t shown publicly.'),
            ),
        ],
        if (step == 3) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Txt(tr('These come from your Verification Center. Organizer verification is separate from your personal signals.')),
          ),
          Col(gap: 8, [
            _check(hasPhone, tr('Phone verified'), tr('Required for all organizers'), () => Nav.push('/verify/phone')),
            _check(hasIdentity, tr('Identity verified'),
                type == 'OFFICIAL' || type == 'ORGANIZATION' ? tr('Strongly recommended for organisations') : tr('Optional'), () => Nav.push('/verify/identity')),
            _check(site.isNotEmpty || !needsSite, tr('Public presence'), needsSite ? tr('We check your website or public page') : tr('Not required for individuals')),
          ]),
        ],
        if (step == 4) ...[
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Txt(tr('Check your details. We’ll review them before Organizer verified appears.'))),
          KeyValue([
            KV(tr('Type'), tr(typeLabel)),
            KV(tr('Name'), name),
            KV(tr('Area'), area),
            if (site.isNotEmpty) KV(tr('Website'), site),
            if (email.isNotEmpty)
              KV(tr('Contact email'), tr('{v} · not public', {'v': email.split('@').length > 1 && email.split('@')[1].isNotEmpty ? '••••@${email.split('@')[1]}' : ''})),
          ]),
          Start(Button(tr('Edit details'), kind: BK.text, onPress: () => setState(() => step = 2))),
          Txt(tr('It doesn’t verify every attendee, or guarantee how an event goes.'), variant: TV.small),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!)),
      ],
    );
  }
}

// ---------- Search ----------

const _suggestions = ['Goa', 'Trekking', 'Photography', 'Hackathon', 'Concert', 'Badminton', 'Networking', 'Cafés'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  SearchResult? result;
  bool loading = false;
  ApiError? error;
  int _seq = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final term = _c.text.trim();
    _debounce?.cancel();
    if (term.length < 2) {
      setState(() => result = null);
      return;
    }
    final mine = ++_seq;
    // Debounce keeps search load sane at scale.
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => loading = true);
      try {
        final r = await DiscoverApi.search(term);
        if (mine == _seq && mounted) {
          setState(() {
            result = r;
            error = null;
          });
        }
      } catch (e) {
        if (mine == _seq && mounted) setState(() => error = e is ApiError ? e : null);
      } finally {
        if (mine == _seq && mounted) setState(() => loading = false);
      }
    });
  }

  void _set(String q) => _c.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final r = result;
    return Screen(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          IconBtn('chevron-left', label: tr('Back'), onPress: goBack),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const FIcon('search', size: 17, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: tr('Search'),
                    child: TextField(
                      controller: _c,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontFamily: Fonts.body, fontSize: 15, color: AppColors.ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: tr('Search plans, people, destinations'),
                        hintStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 15, color: Color(0xFF8A9893)),
                      ),
                    ),
                  ),
                ),
                if (_c.text.isNotEmpty) IconBtn('x', label: tr('Clear search'), onPress: () => _set('')),
              ]),
            ),
          ),
        ]),
      ),
      if (r == null && !loading) ...[
        SectionTitle(tr('Try')),
        ChipWrap(_suggestions.map((s) => Chip(s, onPress: () => _set(s))).toList()),
        Padding(padding: const EdgeInsets.only(top: 16), child: Txt(tr('Search uses your selected area — never your precise live location.'), variant: TV.small)),
      ] else if (loading && r == null)
        const Skeleton()
      else if (error != null && r == null)
        ErrorBlock.of(error!, onRetry: () => _set('${_c.text} '))
      else if (r != null)
        if (r.plans.isEmpty && r.people.isEmpty)
          StateBlock(
            icon: 'search',
            tone: PillTone.neutral,
            title: tr('No results found'),
            body: tr('Try a different activity, destination, event, or keyword.'),
            actions: [StateAction(tr('Create a Plan'), () => Nav.push('/plan/new'))],
          )
        else ...[
          if (r.plans.isNotEmpty) ...[
            SectionTitle(tr('Plans')),
            Group([for (var i = 0; i < r.plans.length; i++) PlanRow(plan: r.plans[i], first: i == 0, onPress: () => Nav.push('/plan/${r.plans[i].id}'))]),
          ],
          if (r.people.isNotEmpty) ...[
            SectionTitle(tr('People')),
            Group([
              for (var i = 0; i < r.people.length; i++)
                Pressable(
                  onPress: () => Nav.push('/user/${r.people[i].user.id}'),
                  label: r.people[i].user.displayName,
                  focusRadius: BorderRadius.zero,
                  builder: (_, _, _) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null),
                    child: Row(children: [
                      Avatar(name: r.people[i].user.displayName, photoUrl: r.people[i].user.photoUrl, id: r.people[i].user.id, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Txt(r.people[i].user.displayName, variant: TV.bodyStrong),
                          Txt(r.people[i].context, variant: TV.small, maxLines: 1),
                        ]),
                      ),
                      const FIcon('chevron-right', size: 16, color: AppColors.inkSoft),
                    ]),
                  ),
                ),
            ]),
          ],
        ],
    ]);
  }
}

// ---------- Edit profile ----------

const _langs = ['English', 'Hindi', 'Kannada', 'Tamil', 'Telugu', 'Marathi', 'Bengali', 'Malayalam'];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final Me _me0 = authOf(context).user!;
  late String area = _me0.area ?? '';
  late String city = _me0.city ?? '';
  late String bio = _me0.bio ?? '';
  late List<String> interests = [..._me0.interests];
  late List<String> languages = [..._me0.languages];
  late List<String> chosenIntents = [..._me0.intents];
  bool busy = false;
  String? error;

  List<V> _toggle<V>(List<V> list, V v) => list.contains(v) ? list.where((x) => x != v).toList() : [...list, v];

  Future<void> _save() async {
    if (area.trim().isEmpty) return setState(() => error = tr('Add an approximate area.'));
    final auth = authOf(context);
    final toast = useToast(context);
    final me = auth.user!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      auth.setUser(await MeApi.update(ProfileUpdate(
        displayName: me.displayName,
        area: area.trim(),
        city: city.trim(),
        bio: bio.trim(),
        photoUrl: me.photoUrl,
        sendPhotoUrl: true,
        interests: interests,
        languages: languages,
        intents: chosenIntents,
      )));
      toast(tr('Profile updated'));
      Nav.back();
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    return Screen(bottom: true, children: [
      Header(kicker: tr('YOUR PROFILE'), title: tr('Edit profile')),
      Group([
        ListRow(first: true, icon: 'user', label: tr('Name'), value: me.displayName, onPress: () => Nav.push('/settings/name')),
        ListRow(icon: 'clock', label: tr('Age range'), value: me.ageRange ?? '—', sub: tr('From your birth year')),
      ]),
      const SizedBox(height: 16),
      Field(label: tr('Area'), value: area, onChanged: (t) => setState(() => area = t), hint: tr('Never your exact home address.')),
      Field(label: tr('City'), value: city, onChanged: (t) => setState(() => city = t)),
      Field(label: tr('Bio'), optional: true, value: bio, onChanged: (t) => setState(() => bio = t), multiline: true, maxLength: 300, hint: '${bio.length}/300'),
      SectionTitle(tr('Interests')),
      ChipWrap(interestsList.map((i) => Chip(i, selected: interests.contains(i), onPress: () => setState(() => interests = _toggle(interests, i)))).toList()),
      SectionTitle(tr('Languages')),
      ChipWrap(_langs.map((l) => Chip(l, selected: languages.contains(l), onPress: () => setState(() => languages = _toggle(languages, l)))).toList()),
      SectionTitle(tr('Open to (optional)')),
      ChipWrap(intents
          .map((i) => Chip(i.label, selected: chosenIntents.contains(i.value), onPress: () => setState(() => chosenIntents = _toggle(chosenIntents, i.value))))
          .toList()),
      Padding(padding: const EdgeInsets.only(top: 8), child: Txt(tr('Dating is optional and never required.'), variant: TV.small)),
      SectionTitle(tr('Trust')),
      Group([ListRow(first: true, icon: 'shield', label: tr('Verification'), onPress: () => Nav.push('/verify'))]),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!)),
      Padding(padding: const EdgeInsets.only(top: 18), child: Button(tr('Save profile'), loading: busy, onPress: _save)),
    ]);
  }
}

// ---------- Help ----------

/// Real ways to get help. "Report a problem" goes to the team's queue in the Admin Console; email opens the mail app
/// with the details support needs (no message is ever claimed as sent unless it was).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool hasFaq = false;

  @override
  void initState() {
    super.initState();
    ContentApi.page('faq').then((_) {
      if (mounted) setState(() => hasFaq = true);
    }).catchError((_) {
      if (mounted) setState(() => hasFaq = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final support = emailOrNull(Business.supportEmail);
    void emailSupport() {
      final body = '\n\n—\n${tr('Please keep this so we can find your account')}:\nAccount #${me.id} · Plans $appVersionString';
      launchUrl(mailto(support!, subject: 'Plans support', body: body));
    }

    return Screen(children: [
      Header(kicker: tr('SUPPORT'), title: tr('Help & support')),
      Txt(tr('Tell us what’s wrong and we’ll look into it. Replies come by email or in your notifications.')),
      SectionTitle(tr('Get help')),
      Group([
        if (hasFaq) ListRow(first: true, icon: 'help-circle', label: tr('Help & FAQ'), sub: tr('Answers to common questions'), onPress: () => Nav.push('/legal/faq')),
        ListRow(
          first: !hasFaq,
          icon: 'message-square',
          label: tr('Report a problem'),
          sub: tr('Something isn’t working, or you need help with your account'),
          onPress: () => openReport(ReportParams(targetType: 'PROBLEM', title: tr('A problem with Plans'))),
        ),
        if (support != null) ListRow(icon: 'mail', label: tr('Email support'), value: support, onPress: emailSupport),
        ListRow(icon: 'shield', label: tr('Safety Center'), sub: tr('Report a person or Plan, block, and safety tips'), onPress: () => Nav.push('/safety')),
      ]),
      SectionTitle(tr('Your account')),
      Group([
        ListRow(first: true, icon: 'download', label: tr('Your data & consent'), onPress: () => Nav.push('/settings/data')),
        ListRow(icon: 'briefcase', label: tr('Business details & Grievance Officer'), onPress: () => Nav.push('/legal/business')),
        ListRow(icon: 'file-text', label: tr('Legal & privacy'), onPress: () => Nav.push('/legal')),
      ]),
      SectionTitle(tr('In an emergency')),
      const EmergencyNote(),
    ]);
  }
}

// ---------- Unavailable ----------

const _fallbacks = <String, (IconName, String, String, bool)>{
  'plan': ('calendar', 'This Plan is no longer available', 'The creator removed it. Your connections from it are unaffected.', true),
  'removedPlan': ('calendar', 'This Plan is no longer available', 'It was removed and can’t be opened. Connections you made through it aren’t affected.', true),
  'event': ('calendar', 'This event is no longer available', 'It was removed and can’t be opened. Connections you made through it aren’t affected.', true),
  'account': ('user', 'This account is no longer available', 'The person deleted their account, so this conversation can’t be opened.', false),
  'restricted': ('lock', 'This account currently has limited access', 'You can’t message or connect with this account right now.', false),
  'suspended': ('user', 'This account is unavailable', 'You can’t view this profile or message this person.', false),
  'group': ('users', 'This group is no longer available', 'The Plan Group was closed, so its messages can’t be viewed.', false),
  'organizer': ('users', 'This organizer is currently unavailable', 'Their profile and events can’t be viewed right now.', true),
  'content': ('eye-off', 'This content is no longer available', 'It was removed and can’t be viewed.', false),
};

class UnavailableScreen extends StatelessWidget {
  final String? reason;
  const UnavailableScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final f = _fallbacks[reason ?? 'content'] ?? _fallbacks['content']!;
    return Screen(children: [
      const Header(),
      StateBlock(
        icon: f.$1,
        tone: PillTone.neutral,
        title: tr(f.$2),
        body: tr(f.$3),
        actions: [
          StateAction(tr('Back'), goBack, f.$4 ? BK.secondary : BK.primary),
          if (f.$4) StateAction(tr('Discover similar Plans'), () => Nav.navigate('/')),
        ],
      ),
    ]);
  }
}
