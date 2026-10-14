import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/focus_data.dart';
import '../state/toast.dart';
import '../util/format.dart';
import '../util/misc.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';

// ---------- Safety Center ----------

const _tips = [
  ('users', 'Share your Plan with someone you trust'),
  ('map-pin', 'Meet in public places'),
  ('lock', 'Keep private information private'),
  ('flag', 'Leave or report if something feels wrong'),
];

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});
  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> with FocusData<SafetyCenterScreen, (List<Report>, List<BlockedUser>)> {
  @override
  Future<(List<Report>, List<BlockedUser>)> load() async {
    final r = await Future.wait([SafetyApi.reports(), SafetyApi.blocked()]);
    return (r[0] as List<Report>, r[1] as List<BlockedUser>);
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final d = data;
    final fresh = d?.$1.where((r) => r.unseenUpdate).firstOrNull;
    final latest = d?.$1.firstOrNull;
    return Screen(children: [
      Header(kicker: tr('SETTINGS'), title: tr('Safety Center')),
      Txt(tr('Tools and information to help you stay safe while meeting people through Plans.')),
      if (loading)
        const Skeleton(rows: 4)
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh, title: tr('Couldn’t load Safety Center'))
      else if (d != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Pressable(
            onPress: fresh != null ? () => Nav.push('/safety/reports/${fresh.id}') : null,
            button: fresh != null,
            focusRadius: BorderRadius.circular(18),
            builder: (_, _, _) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: fresh != null ? AppColors.brandPale : AppColors.surface,
                border: Border.all(color: fresh != null ? const Color(0xFFBCD9CC) : AppColors.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                IconTile(fresh != null ? 'bell' : 'check', tone: fresh != null ? PillTone.ok : PillTone.neutral),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(fresh != null ? tr('1 report has an update') : tr('Nothing needs your attention right now'), variant: TV.bodyStrong),
                    Txt(
                      fresh != null ? '${fresh.targetLabel} · ${tr(reportStatusLabel[fresh.status] ?? fresh.status)}' : tr('Your safety tools are below whenever you need them.'),
                      variant: TV.small,
                    ),
                  ]),
                ),
                if (fresh != null) const FIcon('chevron-right', size: 16, color: AppColors.inkSoft),
              ]),
            ),
          ),
        ),
        SectionTitle(tr('Your safety tools')),
        Group([
          ListRow(
            first: true,
            icon: 'lock',
            label: tr('Blocked people'),
            sub: d.$2.isNotEmpty ? '${d.$2.length} ${d.$2.length == 1 ? 'person' : 'people'}' : tr('No one blocked'),
            onPress: () => Nav.push('/safety/blocked'),
          ),
          ListRow(
            icon: 'flag',
            label: tr('Your reports'),
            sub: latest != null
                ? tr('{v} submitted · latest {v2}', {'v': d.$1.length, 'v2': tr(reportStatusLabel[latest.status] ?? latest.status).toLowerCase()})
                : tr('None submitted'),
            onPress: () => Nav.push('/safety/reports'),
          ),
          ListRow(icon: 'eye', label: tr('Privacy controls'), sub: tr('Control what other people can see'), onPress: () => Nav.push('/safety/visibility')),
          ListRow(icon: 'check', label: tr('Verification'), sub: tr('What verification means — and doesn’t'), onPress: () => Nav.push('/verify')),
          ListRow(icon: 'settings', label: tr('Account security'), sub: tr('Sign-in alerts and devices'), onPress: () => Nav.push('/settings/security')),
        ]),
        SectionTitle(tr('While meeting someone')),
        Group([
          for (var i = 0; i < _tips.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null),
              child: Row(children: [
                FIcon(_tips[i].$1, size: 16, color: AppColors.brand),
                const SizedBox(width: 12),
                Expanded(child: Txt(tr(_tips[i].$2), variant: TV.small, style: const TextStyle(color: AppColors.ink))),
              ]),
            ),
          ListRow(label: tr('Read safety guidelines'), onPress: () => Nav.push('/safety/guidelines')),
        ]),
        SectionTitle(tr('Help')),
        Group([
          ListRow(
            first: true,
            icon: 'flag',
            label: tr('Report a problem'),
            sub: tr('Something wrong that isn’t about one person or Plan'),
            onPress: () => openReport(ReportParams(targetType: 'PROBLEM', title: tr('A problem with Plans'))),
          ),
          ListRow(icon: 'shield', label: tr('Safety guidelines'), sub: tr('Before, during and after a Plan'), onPress: () => Nav.push('/safety/guidelines')),
          ListRow(icon: 'message-circle', label: tr('Contact support'), sub: tr('Talk to our support team'), onPress: () => Nav.push('/help')),
        ]),
        const Padding(padding: EdgeInsets.only(top: 16), child: EmergencyNote()),
      ],
    ]);
  }
}

// ---------- Blocked people ----------

class BlockedPeopleScreen extends StatefulWidget {
  const BlockedPeopleScreen({super.key});
  @override
  State<BlockedPeopleScreen> createState() => _BlockedPeopleScreenState();
}

class _BlockedPeopleScreenState extends State<BlockedPeopleScreen> with FocusData<BlockedPeopleScreen, List<BlockedUser>> {
  @override
  Future<List<BlockedUser>> load() => SafetyApi.blocked();

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    final d = data;
    return Screen(children: [
      Header(kicker: tr('SAFETY CENTER'), title: tr('Blocked people')),
      Txt(tr('Blocked people can’t message you, send connection requests or see your Plans. They aren’t told.')),
      if (loading)
        const Skeleton(rows: 2)
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else if (d == null || d.isEmpty)
        StateBlock(icon: 'lock', tone: PillTone.neutral, title: tr('No blocked people'), body: tr('People you block will appear here.'))
      else
        Group(margin: const EdgeInsets.only(top: 14), [
          for (var i = 0; i < d.length; i++)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null),
              child: Row(children: [
                Avatar(name: d[i].user.displayName, id: d[i].user.id, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(d[i].user.displayName, variant: TV.bodyStrong),
                    if (d[i].context != null) Txt(d[i].context, variant: TV.small),
                    Row(children: [
                      const FIcon('lock', size: 10, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Flexible(child: Txt(tr('Blocked · {date}', {'date': shortDate(d[i].blockedAt)}), variant: TV.caption)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 12),
                Button(
                  tr('Unblock'),
                  compact: true,
                  kind: BK.secondary,
                  a11yLabel: tr('Unblock {displayName}', {'displayName': d[i].user.displayName}),
                  onPress: () {
                    final target = d[i];
                    showConfirm(
                      context,
                      title: tr('Unblock {v}?', {'v': firstName(target.user.displayName)}),
                      body: tr('They’ll be able to see your Plans and send requests again, based on your privacy settings. They won’t be told.'),
                      okLabel: tr('Unblock'),
                      icon: 'unlock',
                      onConfirm: () async {
                        await SafetyApi.unblock(target.user.id);
                        setData(data?.where((x) => x.user.id != target.user.id).toList());
                        toast(tr('{v} unblocked', {'v': firstName(target.user.displayName)}));
                      },
                    );
                  },
                ),
              ]),
            ),
        ]),
    ]);
  }
}

// ---------- Guidelines ----------

const _guideSections = [
  (
    'Before meeting',
    [
      'Review the person’s profile and the Plan details',
      'Keep your phone number, address and other private details private',
      'Choose a public meeting place',
      'Tell someone you trust where you’re going',
    ]
  ),
  ('During the activity', ['Trust your judgement', 'You can leave a Plan at any time', 'You can block or report someone from their profile, a chat or the group']),
  ('If something feels wrong', ['Leave the situation', 'Block the person', 'Report what happened — reports are private']),
];

class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Screen(children: [
      Header(kicker: tr('SAFETY CENTER'), title: tr('Safety guidelines')),
      Txt(tr('Most Plans go exactly as planned. These habits help when meeting people for the first time.')),
      for (final (title, items) in _guideSections) ...[
        SectionTitle(tr(title)),
        Group([
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FIcon('check', size: 15, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(child: Txt(tr(items[i]), variant: TV.small, style: const TextStyle(color: AppColors.ink))),
              ]),
            ),
        ]),
      ],
      const Padding(padding: EdgeInsets.only(top: 18), child: EmergencyNote()),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Txt(
          tr('Verification and reports help, but Plans can’t guarantee anyone’s behaviour or your personal safety. You decide who to meet and when to leave.'),
          variant: TV.small,
        ),
      ),
    ]);
  }
}

// ---------- What others can see ----------

const _visGroups = [
  ('eye', 'People discovering your Plans', ['First name', 'Age range', 'Approximate area', 'Interests', 'Verification signals']),
  ('users', 'Only people in the same Plan', ['Plans you’ve joined', 'Connection intent', 'Group messages']),
  ('lock', 'Never shown to anyone', ['Exact home address', 'Live location', 'Phone number', 'Email', 'Verification documents']),
];

class WhatOthersSeeScreen extends StatelessWidget {
  const WhatOthersSeeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Screen(children: [
      Header(kicker: tr('PRIVACY'), title: tr('What others can see')),
      Txt(tr('Plans shares context, not personal details.')),
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Col(gap: 10, [
          for (final (icon, title, items) in _visGroups)
            Group(padding: const EdgeInsets.all(14), [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  IconTile(icon, size: 32, tone: icon == 'lock' ? PillTone.neutral : PillTone.ok),
                  const SizedBox(width: 10),
                  Expanded(child: Txt(tr(title), variant: TV.bodyStrong)),
                ]),
              ),
              ChipWrap(items.map((i) => Chip(tr(i))).toList(), gap: 6),
            ]),
        ]),
      ),
      Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(16)),
        child: Txt.rich([
          bold('${tr('Why approximate area?')} ', color: AppColors.brandDark),
          TextSpan(text: tr('People only need a rough idea of where you are to find a shared Plan. Meeting points are always public places chosen per Plan.')),
        ], variant: TV.small, style: const TextStyle(color: AppColors.brandDark)),
      ),
      Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Manage privacy settings'), onPress: () => Nav.push('/settings/privacy'))),
    ]);
  }
}

// ---------- Your reports ----------

class YourReportsScreen extends StatefulWidget {
  const YourReportsScreen({super.key});
  @override
  State<YourReportsScreen> createState() => _YourReportsScreenState();
}

class _YourReportsScreenState extends State<YourReportsScreen> with FocusData<YourReportsScreen, List<Report>> {
  @override
  Future<List<Report>> load() => SafetyApi.reports();

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final d = data;
    return Screen(children: [
      Header(kicker: tr('SAFETY CENTER'), title: tr('Your reports')),
      Note(tr('Reports are handled privately. People you report aren’t told who reported them.')),
      if (loading)
        const Skeleton()
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else if (d == null || d.isEmpty)
        StateBlock(
          icon: 'flag',
          tone: PillTone.neutral,
          title: tr('You haven’t submitted any reports'),
          body: tr('If something feels wrong, use Report from a profile, Plan, message or group.'),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Col(gap: 8, [
            for (final r in d)
              Pressable(
                onPress: () => Nav.push('/safety/reports/${r.id}'),
                label: tr('{v} report, {targetLabel}, status {v2}', {
                  'v': tr(reportTypeLabel[r.targetType] ?? r.targetType),
                  'targetLabel': r.targetLabel,
                  'v2': tr(reportStatusLabel[r.status] ?? r.status),
                }),
                focusRadius: BorderRadius.circular(18),
                builder: (_, _, _) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconTile(reportTypeIcon[r.targetType] ?? 'flag', tone: PillTone.neutral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Col(gap: 3, [
                        Row(children: [
                          Expanded(
                            child: Txt(tr(reportTypeLabel[r.targetType] ?? r.targetType).toUpperCase(), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                          ),
                          Pill(tr(reportStatusLabel[r.status] ?? r.status), tone: reportStatusTone[r.status] ?? PillTone.neutral),
                        ]),
                        Txt(r.targetLabel, variant: TV.bodyStrong),
                        Txt('${r.reason} · ${relativeTime(r.submittedAt)}', variant: TV.small),
                        if (r.unseenUpdate) Txt(tr('● Updated'), variant: TV.caption, style: const TextStyle(color: AppColors.brand, fontFamily: Fonts.bodyBold)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
    ]);
  }
}

// ---------- Report detail ----------

class ReportDetailScreen extends StatefulWidget {
  final int id;
  const ReportDetailScreen({super.key, required this.id});
  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> with FocusData<ReportDetailScreen, Report> {
  bool blocked = false;

  @override
  Future<Report> load() => SafetyApi.reportDetail(widget.id);

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    final header = Header(kicker: tr('YOUR REPORTS'), title: tr('Report details'));
    if (loading) return Screen(children: [header, const Loading()]);
    final r = data;
    if (r == null) return Screen(children: [header, if (error != null) ErrorBlock.of(error!, onRetry: refresh)]);

    final statusLabel = tr(reportStatusLabel[r.status] ?? r.status);
    final tone = reportStatusTone[r.status] ?? PillTone.neutral;
    final isFinal = r.status == 'ACTION_TAKEN' || r.status == 'NO_ACTION' || r.status == 'CLOSED';
    final steps = [
      (tr('Submitted'), relativeTime(r.submittedAt), true),
      (tr('Under review'), r.status == 'SUBMITTED' ? tr('Waiting') : tr('Reviewed by our team'), r.status != 'SUBMITTED'),
      (isFinal ? statusLabel : tr('Outcome'), isFinal ? relativeTime(r.updatedAt) : tr('We’ll notify you'), isFinal),
    ];
    final person = r.personName ?? tr('this person');

    return Screen(children: [
      header,
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconTile(reportTypeIcon[r.targetType] ?? 'flag', tone: PillTone.neutral),
            Pill(statusLabel, tone: tone),
          ]),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Txt(r.targetLabel, variant: TV.heading)),
          KeyValue([
            KV(tr('Type'), tr(reportTypeLabel[r.targetType] ?? r.targetType)),
            KV(tr('Reason'), r.reason),
            KV(tr('Submitted'), relativeTime(r.submittedAt)),
          ]),
          if (r.details != null && r.details!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Txt(tr('WHAT YOU TOLD US'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                Padding(padding: const EdgeInsets.only(top: 4), child: Txt(r.details)),
              ]),
            ),
        ]),
      ),
      SectionTitle(tr('Status')),
      Semantics(
        label: tr('Report status'),
        container: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].$3 ? AppColors.brand : AppColors.surface,
                      border: Border.all(color: steps[i].$3 ? AppColors.brand : AppColors.line, width: 1.5),
                    ),
                    child: Text(steps[i].$3 ? '✓' : '${i + 1}',
                        style: TextStyle(color: steps[i].$3 ? Colors.white : AppColors.inkSoft, fontFamily: Fonts.bodyBold, fontSize: 11)),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: steps[i].$3 ? AppColors.brand : AppColors.line),
                    ),
                ]),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Txt(steps[i].$1, variant: TV.bodyStrong), Txt(steps[i].$2, variant: TV.small)]),
                ),
              ]),
            ),
        ]),
      ),
      Banner(icon: 'info', tone: tone, title: tr(reportOutcome[r.status] ?? '')),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Txt(tr('We don’t share details about actions taken on other people’s accounts, and they aren’t told who reported them.'), variant: TV.small),
      ),
      if (r.personId != null && !blocked)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Button(
            tr('Block {v}', {'v': person}),
            kind: BK.secondary,
            icon: 'slash',
            onPress: () => showConfirm(
              context,
              title: tr('Block {v}?', {'v': person}),
              body: tr('They won’t be able to message you, send requests or see your Plans. They won’t be told.'),
              okLabel: tr('Block'),
              okKind: BK.dangerSolid,
              icon: 'slash',
              tone: PillTone.bad,
              onConfirm: () async {
                await SafetyApi.block(r.personId!);
                if (mounted) setState(() => blocked = true);
                toast(tr('Blocked'));
              },
            ),
          ),
        ),
    ]);
  }
}
