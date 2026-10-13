import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
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

const _titles = ['Details', 'When & where', 'People', 'Review'];
const _role = {'CREATOR': 'Creator', 'ORGANIZER': 'Organizer', 'PARTICIPANT': 'Participant'};
final _homeAddress = RegExp(r'\b(flat|apartment|house no|my home|my place)\b', caseSensitive: false);
final _urlRe = RegExp(r'^(https?:\/\/)?[\w-]+(\.[\w-]+)+');

// ---------- Create a Plan ----------

class CreatePlanScreen extends StatefulWidget {
  final String? from;
  final String? draft;
  const CreatePlanScreen({super.key, this.from, this.draft});
  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  List<Category> categories = cachedCategories;
  int step = 1;
  String? busy; // 'publish' | 'draft'
  String? error;
  String? prefill;
  late bool loadingPrefill = widget.from != null || widget.draft != null;

  // Form
  String as_ = 'personal';
  bool official = false;
  String title = '';
  String category = '';
  String description = '';
  DateTime? start;
  DateTime? end;
  late String area;
  late String loc;
  String meetingPoint = '';
  String limit = '';
  late String visibility;
  String regMode = 'APP';
  String regUrl = '';
  String schedule = '';
  String bring = '';
  String eligibility = '';

  @override
  void initState() {
    super.initState();
    final me = authOf(context).user!;
    area = me.area ?? '';
    loc = me.privacy.planLocation == 'PUBLIC_VENUE' ? 'PUBLIC_VENUE' : 'APPROXIMATE';
    visibility = me.privacy.defaultPlanVisibility;
    loadCategories().then((l) {
      if (mounted) setState(() => categories = l);
    });
    final sourceId = int.tryParse(widget.draft ?? widget.from ?? '');
    if (sourceId == null || sourceId == 0) {
      loadingPrefill = false;
      return;
    }
    PlansApi.get(sourceId).then((p) {
      if (!mounted) return;
      setState(() {
        as_ = p.host.kind == 'ORGANIZER' ? 'org' : 'personal';
        official = p.official;
        title = p.title;
        category = p.category;
        description = p.description ?? '';
        area = p.area;
        loc = p.locationMode;
        meetingPoint = p.meetingPoint ?? '';
        limit = '${p.participantLimit}';
        visibility = p.visibility;
        regMode = p.registrationMode;
        regUrl = p.registrationUrl ?? '';
        schedule = p.schedule.map((s) => '${s.time} ${s.what}').join('\n');
        bring = p.bring ?? '';
        eligibility = p.eligibility ?? '';
        start = widget.draft != null && p.startAt != null ? parseIso(p.startAt!) : null;
        prefill = widget.draft != null ? tr('Continuing your draft.') : tr('Details copied from “{title}”. Choose a new date.', {'title': p.title});
      });
    }).catchError((_) {}).whenComplete(() {
      if (mounted) setState(() => loadingPrefill = false);
    });
  }

  void _set(VoidCallback f) => setState(() {
        f();
        error = null;
      });

  String? _validate(int s) {
    if (s == 1) {
      if (title.trim().length < 4) return tr('Give your Plan a title of at least 4 characters.');
      if (category.trim().isEmpty) return tr('Choose a category.');
    }
    if (s == 2) {
      if (start == null) return tr('Choose a date and time.');
      if (start!.isBefore(DateTime.now())) return tr('Choose a time in the future.');
      if (end != null && !end!.isAfter(start!)) return tr('The end must be after the start.');
      if (area.trim().isEmpty) return tr('Add an approximate area.');
      if (meetingPoint.trim().isEmpty) return tr('Add a public meeting point.');
      if (_homeAddress.hasMatch(meetingPoint)) return tr('Meeting points must be public places. Never use a home address.');
    }
    if (s == 3) {
      final n = int.tryParse(limit);
      if (n == null || n < 2 || n > 500) return tr('Set a participant limit between 2 and 500.');
      if (regMode == 'EXTERNAL' && !_urlRe.hasMatch(regUrl.trim())) return tr('Add a valid registration link.');
    }
    return null;
  }

  void _next() {
    final err = _validate(step);
    if (err != null) return setState(() => error = err);
    setState(() => step = step + 1);
  }

  PlanRequest _toRequest(bool isDraft) {
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();
    final timeRe = RegExp(r'^(\d{1,2}(:\d{2})?\s?(AM|PM|am|pm)?)\s+(.*)$');
    return PlanRequest(
      asOrganizer: as_ == 'org',
      official: as_ == 'org' && official,
      title: title.trim(),
      category: category.trim(),
      description: orNull(description),
      area: area.trim(),
      startAt: start?.toUtc().toIso8601String(),
      endAt: end?.toUtc().toIso8601String(),
      locationMode: loc,
      meetingPoint: orNull(meetingPoint),
      participantLimit: int.tryParse(limit) ?? 10,
      visibility: visibility,
      registrationMode: as_ == 'org' ? regMode : 'APP',
      registrationUrl: regMode == 'EXTERNAL' ? regUrl.trim() : null,
      schedule: schedule.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).map((l) {
        final m = timeRe.firstMatch(l);
        return m != null ? ScheduleItem.of(m.group(1)!.toUpperCase(), m.group(4)!) : ScheduleItem.of('', l);
      }).toList(),
      bring: orNull(bring),
      eligibility: orNull(eligibility),
      draft: isDraft,
    );
  }

  Future<void> _submit(bool isDraft) async {
    if (!isDraft) {
      for (final s in [1, 2, 3]) {
        final err = _validate(s);
        if (err != null) {
          setState(() {
            step = s;
            error = err;
          });
          return;
        }
      }
    } else if (title.trim().length < 4) {
      setState(() => error = tr('Add a title to save a draft.'));
      return;
    }
    final toast = useToast(context);
    setState(() => busy = isDraft ? 'draft' : 'publish');
    try {
      final body = _toRequest(isDraft);
      final draftId = int.tryParse(widget.draft ?? '');
      final plan = draftId != null ? await PlansApi.updateDraft(draftId, body) : await PlansApi.create(body);
      if (!isDraft) AnalyticsApi.track('plan_created', {'official': body.official, 'category': body.category});
      toast(isDraft ? tr('Draft saved — only you can see it.') : tr('Your Plan is live.'));
      Nav.replace('/plan/${plan.id}');
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t save your Plan. Try again.'));
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final orgOk = me.organizer?.status == 'VERIFIED';
    if (loadingPrefill) return const Screen(children: [Loading()]);

    if (me.accountStatus == 'RESTRICTED') {
      return Screen(children: [
        Header(kicker: tr('CREATE A PLAN'), title: tr('Unavailable')),
        Banner(
          icon: 'lock',
          tone: PillTone.warn,
          title: tr('Creating Plans is paused on your account'),
          body: tr('Your account has limited access after a review under our community guidelines.'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Button(tr('See what’s affected'), kind: BK.secondary, onPress: () => Nav.replace('/settings/restricted')),
        ),
      ]);
    }

    final visibilityLabels = {'DISCOVERABLE': tr('Discoverable'), 'SHARED_CONTEXT': tr('Shared-context only'), 'PRIVATE': tr('Private link')};

    return Screen(
      bottom: true,
      footer: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: AppColors.paper, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Expanded(
            child: step < 4
                ? Button(tr('Continue'), onPress: _next)
                : Button(official ? tr('Publish event') : tr('Publish Plan'), loading: busy == 'publish', disabled: busy != null, onPress: () => _submit(false)),
          ),
          const SizedBox(width: 8),
          Button(tr('Save as draft'), kind: BK.secondary, loading: busy == 'draft', disabled: busy != null, onPress: () => _submit(true)),
        ]),
      ),
      children: [
        Header(kicker: tr('CREATE A PLAN'), title: tr(_titles[step - 1]), onBack: () => step > 1 ? setState(() => step = step - 1) : Nav.back()),
        StepBars(total: 4, current: step),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Txt(tr('Step {step} of 4', {'step': step}), variant: TV.caption)),
        if (prefill != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Banner(icon: 'copy', tone: PillTone.neutral, title: prefill!)),

        if (step == 1) ...[
          SectionTitle(tr('Create as')),
          RadioCards<String>(
            label: tr('Create as'),
            value: as_,
            onChange: (v) => _set(() {
              as_ = v;
              if (v == 'personal') official = false;
            }),
            options: [
              RadioOption('personal', tr('Yourself'), sub: tr('A personal Plan from {displayName}', {'displayName': me.displayName})),
              if (me.organizer != null)
                RadioOption(
                  'org',
                  me.organizer!.name,
                  disabled: !orgOk,
                  sub: orgOk ? tr('Organizer Plan · Organizer verified') : tr('Available after organizer verification'),
                ),
            ],
          ),
          if (as_ == 'org')
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
              child: ListRow(
                first: true,
                label: tr('Official event'),
                sub: tr('Shows the Official event badge. Only for events you’re authorised to represent.'),
                right: Switch(value: official, onChange: (v) => _set(() => official = v), label: tr('Official event')),
              ),
            ),
          const SizedBox(height: 16),
          Field(label: tr('What are you doing?'), value: title, onChanged: (t) => _set(() => title = t), placeholder: tr('Cubbon Park sunrise walk'), maxLength: 80),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Txt(tr('Category'), variant: TV.caption, style: const TextStyle(color: AppColors.ink, fontSize: 13, fontFamily: Fonts.bodyBold)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ChipWrap(categories.map((c) => Chip(categoryLabel(c.name), selected: category == c.name, onPress: () => _set(() => category = c.name))).toList()),
          ),
          Field(
            label: tr('Description'),
            optional: true,
            value: description,
            onChanged: (t) => _set(() => description = t),
            multiline: true,
            maxLength: 1500,
            placeholder: tr('What you’ll do and who it’s for'),
          ),
        ],

        if (step == 2) ...[
          DateField(label: tr('Starts'), value: start, onChange: (d) => _set(() => start = d), minimumDate: DateTime.now()),
          DateField(label: tr('Ends'), optional: true, value: end, onChange: (d) => _set(() => end = d), minimumDate: start ?? DateTime.now()),
          Field(
            label: tr('Area'),
            value: area,
            onChanged: (t) => _set(() => area = t),
            placeholder: tr('Indiranagar, Bengaluru'),
            hint: tr('Shown to everyone as an approximate area.'),
          ),
          SectionTitle(tr('Location')),
          RadioCards<String>(
            label: tr('Location type'),
            value: loc,
            onChange: (v) => _set(() => loc = v),
            options: [
              RadioOption('APPROXIMATE', tr('Approximate area until people join'), sub: tr('Participants see the exact public meeting point after joining')),
              RadioOption('PUBLIC_VENUE', tr('Public venue'), sub: tr('Shown to everyone — only for public places')),
              if (official) RadioOption('OFFICIAL_VENUE', tr('Official event venue'), sub: tr('The event’s published venue')),
            ],
          ),
          const SizedBox(height: 14),
          Field(
            label: loc == 'APPROXIMATE' ? tr('Meeting point (shared after joining)') : tr('Venue'),
            value: meetingPoint,
            onChanged: (t) => _set(() => meetingPoint = t),
            placeholder: tr('Cubbon Park, bandstand'),
            hint: tr('Meeting points must be public places. Never use a home address.'),
          ),
        ],

        if (step == 3) ...[
          Field(
            label: tr('Participant limit'),
            value: limit,
            onChanged: (t) => _set(() => limit = t),
            formatters: [digitsOnly],
            keyboardType: TextInputType.number,
            placeholder: '12',
            hint: tr('Including you.'),
          ),
          SectionTitle(tr('Visibility')),
          RadioCards<String>(
            label: tr('Visibility'),
            value: visibility,
            onChange: (v) => _set(() => visibility = v),
            options: [
              RadioOption('DISCOVERABLE', tr('Discoverable'), sub: tr('Can appear in relevant discovery results nearby.')),
              RadioOption('SHARED_CONTEXT', tr('Shared-context only'), sub: tr('Only people with a shared event, destination or connection can find it.')),
              RadioOption('PRIVATE', tr('Private link'), sub: tr('Not publicly discoverable. Only people with the link can join.')),
            ],
          ),
          if (as_ == 'org') ...[
            SectionTitle(tr('Registration')),
            RadioCards<String>(
              label: tr('Registration'),
              value: regMode,
              onChange: (v) => _set(() => regMode = v),
              options: [
                RadioOption('APP', tr('Join in the app'), sub: tr('People join the Plan here')),
                RadioOption('EXTERNAL', tr('External registration required'), sub: tr('People also register on your site')),
              ],
            ),
            if (regMode == 'EXTERNAL')
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Field(
                  label: tr('Registration link'),
                  value: regUrl,
                  onChanged: (t) => _set(() => regUrl = t),
                  capitalization: TextCapitalization.none,
                  keyboardType: TextInputType.url,
                  placeholder: tr('https://'),
                  hint: tr('Plans doesn’t sell tickets or take payments.'),
                ),
              ),
            const SizedBox(height: 14),
            Field(
              label: tr('Schedule'),
              optional: true,
              value: schedule,
              onChanged: (t) => _set(() => schedule = t),
              multiline: true,
              placeholder: tr('One item per line, e.g.\n7:00 AM Meet at the bandstand'),
            ),
          ] else
            const SizedBox(height: 14),
          Field(label: tr('What to bring'), optional: true, value: bring, onChanged: (t) => _set(() => bring = t), placeholder: tr('Water, comfortable shoes')),
          Field(label: tr('Who can join'), optional: true, value: eligibility, onChanged: (t) => _set(() => eligibility = t), placeholder: tr('Beginners welcome · 18+')),
        ],

        if (step == 4) ...[
          if (official) Padding(padding: const EdgeInsets.only(bottom: 10), child: Pill(tr('Official event'), icon: 'calendar', tone: PillTone.ok)),
          KeyValue([
            KV(tr('Host'), as_ == 'org' ? (me.organizer?.name ?? '') : me.displayName),
            KV(tr('Title'), title),
            KV(tr('Category'), categoryLabel(category)),
            KV(tr('When'), start != null ? planDate(start!.toUtc().toIso8601String(), end?.toUtc().toIso8601String()) : tr('Not set')),
            KV(tr('Area'), tr('{area} · approximate', {'area': area})),
            KV(loc == 'APPROXIMATE' ? tr('Meeting point') : tr('Venue'), '$meetingPoint${loc == 'APPROXIMATE' ? tr(' (after joining)') : ''}'),
            KV(tr('Limit'), tr('{n} people', {'n': limit})),
            KV(tr('Visibility'), visibilityLabels[visibility] ?? visibility),
            if (as_ == 'org') KV(tr('Registration'), regMode == 'APP' ? tr('In the app') : tr('External · {regUrl}', {'regUrl': regUrl})),
          ]),
          Start(Button(tr('Edit'), kind: BK.text, onPress: () => setState(() => step = 1))),
          Note(tr('A Plan Group opens for participants automatically. Phone numbers are never shared.'), icon: 'shield'),
        ],

        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!)),
      ],
    );
  }
}

// ---------- Plan detail ----------

class PlanDetailScreen extends StatefulWidget {
  final int id;
  final String? from;
  final String? mode;
  const PlanDetailScreen({super.key, required this.id, this.from, this.mode});
  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> with FocusData<PlanDetailScreen, PlanDetail> {
  bool showParticipants = false;
  bool reminderDismissed = false;
  bool busy = false;

  @override
  Future<PlanDetail> load() async {
    final p = await PlansApi.get(widget.id);
    AnalyticsApi.track('plan_viewed', {'official': p.official});
    return p;
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    if (loading) return const Scaffold(backgroundColor: AppColors.paper, body: SafeArea(child: Loading()));
    final plan = data;
    if (plan == null) {
      final gone = error?.status == 404 || error?.status == 410;
      return Screen(children: [
        const SizedBox(height: 56),
        if (gone)
          StateBlock(
            icon: 'calendar',
            tone: PillTone.neutral,
            title: tr('This Plan is no longer available'),
            body: tr('It was removed and can’t be opened. Connections you made through it aren’t affected.'),
            actions: [StateAction(tr('Back'), goBack, BK.secondary), StateAction(tr('Discover similar Plans'), () => Nav.navigate('/'))],
          )
        else if (error != null)
          ErrorBlock.of(error!, onRetry: refresh),
      ]);
    }

    final official = plan.official;
    /// Whole sentences for Plans vs official events, so each language keeps natural grammar.
    String pe(String forPlan, String forEvent) => tr(official ? forEvent : forPlan);
    final cancelled = plan.status == 'CANCELLED';
    final completed = plan.status == 'COMPLETED';
    final inactive = cancelled || completed;
    final full = plan.participantCount >= plan.participantLimit;
    final capacity = tr('{participantCount} of {participantLimit} joined', {'participantCount': plan.participantCount, 'participantLimit': plan.participantLimit});
    final reminder = widget.mode == 'reminder' && plan.startAt != null && !inactive ? _reminderCopy(plan) : null;

    Future<void> join() async {
      setState(() => busy = true);
      try {
        setData(await PlansApi.join(plan.id));
        AnalyticsApi.track('plan_joined');
        toast(tr('You joined {title}', {'title': plan.title}));
      } catch (e) {
        toast(e is ApiError ? e.message : tr('Couldn’t join. Try again.'));
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }

    void share() {
      SharePlus.instance
          .share(ShareParams(
            text: tr('{title} · {v} · {area}\nhttps://plans.app/p/{id}{v2}', {
              'title': plan.title,
              'v': planDate(plan.startAt, plan.endAt),
              'area': plan.area,
              'id': plan.id,
              'v2': plan.shareCode != null ? '?c=${plan.shareCode}' : '',
            }),
          ))
          .catchError((_) => ShareResult.unavailable);
    }

    void report() => openReport(ReportParams(
          targetType: plan.official ? 'EVENT' : 'PLAN',
          targetId: plan.id,
          title: '“${plan.title}”',
          sub: '${plan.host.subtitle} · ${plan.host.name}',
        ));

    Future<void> confirmLeave() => showConfirm(
          context,
          title: tr('Leave this Plan?'),
          body: tr('You’ll leave the Plan Group too. Connections you made stay with you.'),
          okLabel: tr('Leave Plan'),
          okKind: BK.dangerSolid,
          icon: 'log-out',
          tone: PillTone.bad,
          onConfirm: () async => setData(await PlansApi.leave(plan.id)),
        );

    Future<void> confirmRemove(PlanMember member) => showConfirm(
          context,
          title: tr('Remove from Plan?'),
          body: tr('They’ll leave the Plan and its group, and be told privately. They can’t rejoin this Plan.'),
          okLabel: tr('Remove'),
          okKind: BK.dangerSolid,
          icon: 'user-x',
          tone: PillTone.bad,
          onConfirm: () async => setData(await PlansApi.removeParticipant(plan.id, member.user.id)),
        );

    Future<void> openCancel() => _showCancelSheet(context, official, onConfirm: (reason) async {
          final updated = await PlansApi.cancel(plan.id, reason);
          setData(updated);
          toast(pe('Plan cancelled. Participants were notified.', 'Event cancelled. Participants were notified.'));
        });

    Future<void> manage() => showActionSheet(context, title: pe('Manage Plan', 'Manage event'), sub: plan.title, actions: [
          if (!inactive) ...[
            SheetAction(tr('Edit details'), 'edit-2', () => Nav.push('/plan/${plan.id}/edit'), sub: tr('Participants see exactly what changed')),
            SheetAction(tr('Post an announcement'), 'volume-2', () => Nav.push('/plan/${plan.id}/announce'), sub: tr('Pinned in the group and sent to everyone')),
          ],
          SheetAction(tr('Participants'), 'users', () => setState(() => showParticipants = true), sub: tr('Remove, report or block')),
          if (!inactive && plan.status != 'DRAFT') ...[
            SheetAction(
              pe('Mark Plan as completed', 'Mark event as completed'),
              'check',
              () => showConfirm(
                context,
                title: pe('Mark Plan as completed?', 'Mark event as completed?'),
                body: tr('The Plan Group becomes read-only. Participants can keep the connections they made.'),
                okLabel: tr('Mark completed'),
                icon: 'check',
                onConfirm: () async => setData(await PlansApi.complete(plan.id)),
              ),
            ),
            SheetAction(pe('Cancel Plan', 'Cancel event'), 'x', openCancel, danger: true, sub: tr('Everyone is notified')),
          ],
          if (plan.status == 'DRAFT')
            SheetAction(
              tr('Delete draft'),
              'trash-2',
              () => showConfirm(
                context,
                title: tr('Delete this draft?'),
                body: tr('Only you can see drafts. This can’t be undone.'),
                okLabel: tr('Delete draft'),
                okKind: BK.dangerSolid,
                icon: 'trash-2',
                tone: PillTone.bad,
                onConfirm: () async {
                  await PlansApi.remove(plan.id);
                  Nav.navigate('/plans');
                },
              ),
              danger: true,
            ),
        ]);

    Future<void> memberMenu(PlanMember m) => showActionSheet(context, title: m.user.displayName, sub: tr(_role[m.role] ?? m.role), actions: [
          SheetAction(tr('View profile'), 'user', () => Nav.push('/user/${m.user.id}')),
          SheetAction(
            tr('Report {v}', {'v': firstName(m.user.displayName)}),
            'flag',
            () => openReport(ReportParams(
              targetType: 'PARTICIPANT',
              targetId: m.user.id,
              title: m.user.displayName,
              sub: tr('Participant in {title}', {'title': plan.title}),
              personId: m.user.id,
              personName: firstName(m.user.displayName),
            )),
            danger: true,
            sub: tr('Reports are private'),
          ),
          if (plan.owner && m.role == 'PARTICIPANT')
            SheetAction(tr('Remove from Plan'), 'user-x', () => confirmRemove(m), danger: true, sub: tr('They’re told privately')),
        ]);

    Widget section(Widget child, {Color? bg, Color? border, String? label}) => Semantics(
          label: label,
          container: label != null,
          child: Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg ?? AppColors.surface, border: Border.all(color: border ?? AppColors.line), borderRadius: BorderRadius.circular(18)),
            child: child,
          ),
        );

    final fromNotifLabel = switch (widget.mode) {
      'updated' => tr('changes are highlighted'),
      'reminder' => tr('your reminder'),
      'cancelled' => tr('this Plan was cancelled'),
      _ => tr('Plan details'),
    };

    final hostIsMe = plan.owner && plan.host.kind == 'USER';

    return Screen(
      padded: false,
      top: false,
      children: [
        SizedBox(
          height: 250,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.brandDark)),
            PlanCover(category: plan.category, coverImageUrl: plan.coverImageUrl, iconSize: 110),
            const Positioned.fill(child: ColoredBox(color: Color.fromRGBO(15, 25, 23, 0.2))),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    IconBtn('chevron-left', label: widget.from == 'notification' ? tr('Back to notifications') : tr('Back'), filled: true, onPress: goBack),
                    IconBtn('more-horizontal',
                        label: tr('More options for this Plan'),
                        filled: true,
                        onPress: () => showActionSheet(context, title: plan.title, sub: '${planDate(plan.startAt, plan.endAt)} · ${plan.area}', actions: [
                              SheetAction(tr('Share'), 'share-2', share),
                              if (plan.owner) SheetAction(pe('Manage Plan', 'Manage event'), 'settings', manage),
                              if (!plan.owner) SheetAction(pe('Report Plan', 'Report event'), 'flag', report, danger: true, sub: tr('Reports are private')),
                            ])),
                  ]),
                ),
              ),
            ),
            Positioned(left: 16, bottom: 26, child: categoryBadge(categoryLabel(plan.category))),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -16),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.from == 'notification')
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const FIcon('bell', size: 12, color: AppColors.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Txt.rich([
                        TextSpan(text: tr('From Notifications'), style: const TextStyle(fontFamily: Fonts.bodyBold)),
                        TextSpan(text: ' · $fromNotifLabel'),
                      ], variant: TV.small),
                    ),
                  ]),
                ),
              Row(children: [
                const FIcon('map-pin', size: 12, color: AppColors.brand),
                const SizedBox(width: 4),
                Expanded(child: Txt('${plan.area.toUpperCase()} ${tr('· APPROXIMATE')}', variant: TV.kicker, maxLines: 1)),
                PlanStatusPill(plan.status),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Txt(plan.title, variant: TV.display, style: const TextStyle(fontSize: 28, height: 32 / 28), header: true),
              ),
              if (plan.official)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Pill(tr('Official event'),
                      icon: 'calendar',
                      tone: PillTone.ok,
                      onPress: () => showSignalExplainer(context, const ExplainSignal('OFFICIAL')),
                      a11yLabel: tr('Official event. Learn what this means')),
                ),
              if (cancelled)
                section(
                  bg: const Color(0xFFFAEAEA),
                  border: const Color(0xFFEFC9C9),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const FIcon('x', size: 16, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Txt(plan.official ? tr('This event was cancelled') : tr('This Plan was cancelled'),
                            variant: TV.bodyStrong, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ]),
                    if (plan.cancelReason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Txt('“${plan.cancelReason}”', variant: TV.small)),
                    Padding(padding: const EdgeInsets.only(top: 4), child: Txt(tr('The Plan Group is now read-only. Connections you made stay with you.'), variant: TV.small)),
                  ]),
                ),
              if (plan.latestChange != null && !inactive && (plan.status == 'UPDATED' || widget.mode == 'updated'))
                section(
                  bg: const Color(0xFFF2F8FB),
                  border: const Color(0xFFCFE2EA),
                  label: tr('What changed'),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const FIcon('bell', size: 14, color: Color(0xFF2B5C74)),
                        const SizedBox(width: 6),
                        Expanded(child: Txt(tr('What changed'), variant: TV.bodyStrong, style: const TextStyle(color: Color(0xFF2B5C74)))),
                        Txt('${plan.latestChange!.by} · ${relativeTime(plan.latestChange!.at)}', variant: TV.caption),
                      ]),
                    ),
                    Diff(plan.latestChange!.changes),
                  ]),
                ),
              if (reminder != null)
                section(
                  bg: const Color(0xFFF7FBE0),
                  border: const Color(0xFFE3EC9E),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const FIcon('clock', size: 15, color: AppColors.ink),
                      const SizedBox(width: 6),
                      Expanded(child: Txt(reminder.$1, variant: TV.bodyStrong)),
                    ]),
                    Padding(padding: const EdgeInsets.only(top: 4), child: Txt(reminder.$2, variant: TV.small)),
                    Start(Button(tr('Reminder settings'), kind: BK.text, compact: true, onPress: () => Nav.push('/notifications/settings'))),
                  ]),
                ),
              if (!plan.owner && !inactive && !reminderDismissed)
                section(
                  label: tr('Safety reminder'),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const IconTile('shield'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Txt(tr('Meeting someone new?'), variant: TV.bodyStrong),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Txt(tr('Keep your first meeting in a public place and avoid sharing private information.'), variant: TV.small),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            Button(tr('Got it'), compact: true, onPress: () => setState(() => reminderDismissed = true)),
                            Button(tr('Safety tips'), compact: true, kind: BK.secondary, onPress: () => Nav.push('/safety/guidelines')),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              Semantics(
                label: tr('Plan details'),
                container: true,
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Detail(
                      icon: 'calendar',
                      label: tr('DATE & TIME'),
                      value: planDate(plan.startAt, plan.endAt),
                      updated: (plan.latestChange?.changes.any((c) => c.field == 'startAt') ?? false) && plan.status == 'UPDATED',
                    ),
                    _Detail(
                      icon: 'map-pin',
                      label: plan.meetingPointHidden ? tr('MEETING POINT · SHARED AFTER JOINING') : tr('MEETING POINT · PUBLIC'),
                      value: plan.meetingPointHidden ? tr('{area} · approximate', {'area': plan.area}) : (plan.meetingPoint ?? plan.area),
                      updated: (plan.latestChange?.changes.any((c) => c.field == 'meetingPoint') ?? false) && plan.status == 'UPDATED',
                    ),
                    _Detail(icon: 'users', label: tr('CAPACITY'), value: capacity, last: true),
                  ]),
                ),
              ),
              if (completed)
                section(
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const FIcon('check', size: 15, color: AppColors.brand),
                      const SizedBox(width: 6),
                      Expanded(child: Txt(plan.official ? tr('This event is complete') : tr('This Plan is complete'), variant: TV.bodyStrong)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Txt(tr('The Plan Group is archived and read-only. Connections people made stay with them.'), variant: TV.small),
                    ),
                    if (plan.owner)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Start(Button(tr('Create another Plan'), compact: true, onPress: () => Nav.push('/plan/new', {'from': '${plan.id}'}))),
                      ),
                  ]),
                ),
              if (plan.description != null && plan.description!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 16), child: Txt(plan.description, style: const TextStyle(fontSize: 15, height: 22 / 15))),
              if (plan.schedule.isNotEmpty || _has(plan.bring) || _has(plan.eligibility) || _has(plan.instructions))
                section(
                  label: tr('Event information'),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (plan.schedule.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.only(bottom: 8), child: Txt(tr('SCHEDULE'), variant: TV.kicker)),
                      for (final s in plan.schedule)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 66, child: Text(s.time, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: AppColors.ink))),
                            const SizedBox(width: 12),
                            Expanded(child: Txt(s.what, variant: TV.small)),
                          ]),
                        ),
                    ],
                    Padding(
                      padding: EdgeInsets.only(top: plan.schedule.isNotEmpty ? 12 : 0, bottom: 6),
                      child: Txt(tr('GOOD TO KNOW'), variant: TV.kicker),
                    ),
                    for (final (k, v) in [(tr('What to bring'), plan.bring), (tr('Who can join'), plan.eligibility), (tr('Instructions'), plan.instructions)])
                      if (_has(v))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Txt(k, variant: TV.caption),
                            Txt(v, variant: TV.small, style: const TextStyle(color: AppColors.ink)),
                          ]),
                        ),
                  ]),
                ),
              section(
                label: plan.host.kind == 'ORGANIZER' ? tr('Hosted by') : tr('Created by'),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Txt(plan.host.kind == 'ORGANIZER' ? tr('HOSTED BY') : tr('CREATED BY'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Avatar(name: plan.host.name, photoUrl: plan.host.photoUrl, id: plan.host.id, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Txt(hostIsMe ? tr('You') : plan.host.name, variant: TV.bodyStrong),
                          Txt(plan.host.subtitle, variant: TV.small),
                        ]),
                      ),
                      if (!hostIsMe)
                        Button(
                          plan.host.kind == 'ORGANIZER' ? tr('View organizer') : tr('View profile'),
                          compact: true,
                          kind: BK.secondary,
                          onPress: () => Nav.push(plan.host.kind == 'ORGANIZER' ? '/organizer/${plan.host.id}' : '/user/${plan.host.id}'),
                        ),
                    ]),
                  ),
                  TrustSignals(signals: plan.host.signals, name: plan.host.name),
                  if (plan.why != null && plan.why!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(children: [
                        const FIcon('star', size: 11, color: AppColors.brand),
                        const SizedBox(width: 5),
                        Expanded(child: Txt(plan.why, variant: TV.small)),
                      ]),
                    ),
                ]),
              ),
              section(
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Txt(tr('Participants'), variant: TV.bodyStrong)),
                    Button(
                      showParticipants ? tr('Hide') : tr('Show all'),
                      kind: BK.text,
                      compact: true,
                      onPress: () => setState(() => showParticipants = !showParticipants),
                      a11yLabel: showParticipants ? tr('Hide participants') : tr('Show all participants'),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      // Avatars overlap by 8px, like marginLeft: -8.
                      if (plan.members.isNotEmpty)
                        SizedBox(
                          width: 36 + 28.0 * ((plan.members.length > 5 ? 5 : plan.members.length) - 1),
                          height: 36,
                          child: Stack(children: [
                            for (var i = 0; i < plan.members.length && i < 5; i++)
                              Positioned(
                                left: 28.0 * i,
                                child: Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)),
                                  child: Avatar(name: plan.members[i].user.displayName, photoUrl: plan.members[i].user.photoUrl, id: plan.members[i].user.id, size: 32),
                                ),
                              ),
                          ]),
                        ),
                      const SizedBox(width: 10),
                      Expanded(child: Txt(capacity, variant: TV.small)),
                    ]),
                  ),
                  if (showParticipants)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (var i = 0; i < plan.members.length; i++)
                          _MemberRow(
                            member: plan.members[i],
                            first: i == 0,
                            onOpen: plan.members[i].me ? null : () => Nav.push('/user/${plan.members[i].user.id}'),
                            onMore: () => memberMenu(plan.members[i]),
                          ),
                      ]),
                    ),
                ]),
              ),
              if (plan.registrationMode == 'EXTERNAL')
                section(
                  label: tr('Registration'),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const FIcon('link', size: 14, color: AppColors.ink),
                      const SizedBox(width: 6),
                      Expanded(child: Txt(tr('External registration required'), variant: TV.bodyStrong)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Txt(tr('Join the Plan here, and also register on the organizer’s site. Plans doesn’t sell tickets or take payments.'), variant: TV.small),
                    ),
                    if (plan.registrationUrl != null && !inactive)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Start(Button(
                          tr('Register on organizer’s site ↗'),
                          compact: true,
                          kind: BK.secondary,
                          onPress: () {
                            final u = plan.registrationUrl!;
                            launchUrl(Uri.parse(u.startsWith('http') ? u : 'https://$u'), mode: LaunchMode.externalApplication);
                          },
                        )),
                      ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Col(gap: 8, [
                  if (!plan.owner && !inactive)
                    plan.joined
                        ? Button(tr('Joined · Leave Plan'), kind: BK.secondary, icon: 'check', onPress: confirmLeave)
                        : Button(full ? tr('Full') : pe('Join Plan', 'Join event'), disabled: full, loading: busy, onPress: join),
                  if (plan.owner)
                    Button(pe('Manage Plan', 'Manage event'), icon: 'settings', kind: plan.status == 'DRAFT' ? BK.secondary : BK.primary, onPress: manage),
                  if (plan.status == 'DRAFT' && plan.owner)
                    Button(tr('Continue editing draft'), onPress: () => Nav.push('/plan/new', {'draft': '${plan.id}'})),
                  Row(children: [
                    Expanded(child: Button(tr('Share'), icon: 'share-2', kind: BK.secondary, onPress: share)),
                    if (!plan.owner) ...[const SizedBox(width: 8), Expanded(child: Button(tr('Report'), icon: 'flag', kind: BK.secondary, onPress: report))],
                  ]),
                  if (plan.groupConversationId != null && (plan.joined || plan.owner))
                    Button(
                      inactive ? tr('View Plan Group (read-only)') : tr('Open Plan Group'),
                      icon: 'users',
                      kind: BK.secondary,
                      onPress: () => Nav.push('/group/${plan.groupConversationId}'),
                    ),
                  if (cancelled) Button(tr('Find similar Plans'), kind: BK.text, onPress: () => Nav.navigate('/')),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: section(
                  label: tr('Safety'),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const FIcon('shield', size: 14, color: AppColors.brand),
                        const SizedBox(width: 6),
                        Txt(tr('Safety'), variant: TV.bodyStrong),
                      ]),
                    ),
                    for (final (label, run) in [
                      (tr('Safety guidelines'), () => Nav.push('/safety/guidelines')),
                      (tr('What others can see'), () => Nav.push('/safety/visibility')),
                      if (!plan.owner) (pe('Report this Plan', 'Report this event'), report),
                    ])
                      Pressable(
                        onPress: run,
                        label: label,
                        focusRadius: BorderRadius.zero,
                        builder: (_, _, _) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                          child: Row(children: [
                            Expanded(child: Txt(label, variant: TV.small, style: const TextStyle(color: AppColors.ink))),
                            const FIcon('arrow-right', size: 13, color: AppColors.brand),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

bool _has(String? s) => s != null && s.isNotEmpty;

(String, String) _reminderCopy(PlanDetail plan) {
  final mins = (parseIso(plan.startAt!).difference(DateTime.now()).inMilliseconds / 60000).round();
  final others = plan.participantCount - 1 < 0 ? 0 : plan.participantCount - 1;
  final title = mins <= 0
      ? tr('Happening now')
      : mins < 90
          ? (mins < 60 ? tr('Starts in {n} min', {'n': mins}) : tr('Starts in 1 hour'))
          : mins < 36 * 60
              ? tr('Starts tomorrow')
              : tr('Starts {date}', {'date': planDate(plan.startAt)});
  final where = plan.meetingPoint != null && !plan.meetingPointHidden ? tr(' Meet at {meetingPoint} — a public place.', {'meetingPoint': plan.meetingPoint}) : '';
  return (
    title,
    tr(others == 1 ? '{date}. 1 other is going.{where}' : '{date}. {others} others are going.{where}', {
      'date': planDate(plan.startAt, plan.endAt),
      'others': others,
      'where': where,
    }),
  );
}

class _Detail extends StatelessWidget {
  final IconName icon;
  final String label;
  final String value;
  final bool updated;
  final bool last;
  const _Detail({required this.icon, required this.label, required this.value, this.updated = false, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(children: [
        FIcon(icon, size: 18, color: AppColors.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: AppColors.inkSoft)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(value, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 14, color: AppColors.ink))),
          ]),
        ),
        if (updated) ...[const SizedBox(width: 12), Pill(tr('Updated'), tone: PillTone.blue)],
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final PlanMember member;
  final bool first;
  final VoidCallback? onOpen;
  final VoidCallback onMore;
  const _MemberRow({required this.member, required this.first, required this.onOpen, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final sig = topSignal(m.user.signals);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.divider))),
      child: Row(children: [
        Expanded(
          child: Pressable(
            onPress: onOpen,
            label: m.me ? tr('You') : m.user.displayName,
            builder: (_, _, _) => Row(children: [
              Avatar(name: m.user.displayName, photoUrl: m.user.photoUrl, id: m.user.id, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Col(gap: 2, [
                  Txt(m.me ? tr('You') : m.user.displayName, variant: TV.bodyStrong),
                  if (sig != null) Pill(sig, icon: 'check', tone: PillTone.ok),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        Txt(tr(_role[m.role] ?? m.role), variant: TV.caption),
        if (!m.me) ...[
          const SizedBox(width: 6),
          IconBtn('more-horizontal', label: tr('Options for {displayName}', {'displayName': m.user.displayName}), onPress: onMore),
        ],
      ]),
    );
  }
}

Future<void> _showCancelSheet(BuildContext context, bool official, {required Future<void> Function(String reason) onConfirm}) {
  var reason = '';
  var busy = false;
  var error = '';
  return showSheet<void>(
    context,
    label: tr(official ? 'Cancel this event' : 'Cancel this Plan'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Txt(tr(official ? 'Cancel this event?' : 'Cancel this Plan?'), variant: TV.heading),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Txt(tr('Everyone who joined is notified with your reason. The Plan Group becomes read-only.'), variant: TV.small),
        ),
        Field(
          label: tr('Reason'),
          value: reason,
          onChanged: (t) => setState(() => reason = t),
          placeholder: tr('The ground is unavailable this week.'),
          maxLength: 200,
        ),
        if (error.isNotEmpty) Banner(icon: 'alert-circle', tone: PillTone.bad, title: error),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(child: Button(tr('Keep'), kind: BK.secondary, onPress: () => Navigator.of(ctx).pop())),
            const SizedBox(width: 8),
            Expanded(
              child: Button(
                tr(official ? 'Cancel event' : 'Cancel Plan'),
                kind: BK.dangerSolid,
                loading: busy,
                disabled: reason.trim().length < 3,
                onPress: () async {
                  setState(() {
                    busy = true;
                    error = '';
                  });
                  try {
                    await onConfirm(reason.trim());
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t cancel.'));
                  } finally {
                    if (ctx.mounted) setState(() => busy = false);
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}

// ---------- Edit details ----------

/// Edit event details. Time/place changes always notify participants with exactly what changed.
class EditDetailsScreen extends StatefulWidget {
  final int id;
  const EditDetailsScreen({super.key, required this.id});
  @override
  State<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends State<EditDetailsScreen> {
  PlanDetail? plan;
  DateTime? start;
  String meet = '';
  String limit = '';
  String instructions = '';
  bool notify = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    PlansApi.get(widget.id).then((p) {
      if (!mounted) return;
      setState(() {
        plan = p;
        start = p.startAt != null ? parseIso(p.startAt!) : null;
        meet = p.meetingPoint ?? '';
        limit = '${p.participantLimit}';
        instructions = p.instructions ?? '';
      });
    }).catchError((e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t load this Plan.'));
    });
  }

  List<FieldChange> get changes {
    final p = plan;
    if (p == null) return [];
    final out = <FieldChange>[];
    if (start != null && p.startAt != null && !start!.isAtSameMomentAs(parseIso(p.startAt!))) {
      out.add(FieldChange.of(tr('Date & time'), planDate(p.startAt), planDate(start!.toUtc().toIso8601String()), field: 'startAt'));
    }
    if (meet.trim() != (p.meetingPoint ?? '')) out.add(FieldChange.of(tr('Meeting point'), p.meetingPoint ?? '—', meet.trim(), field: 'meetingPoint'));
    if (int.tryParse(limit) != p.participantLimit) out.add(FieldChange.of(tr('Participant limit'), '${p.participantLimit}', limit, field: 'participantLimit'));
    if (instructions.trim() != (p.instructions ?? '')) {
      out.add(FieldChange.of(tr('Instructions'), p.instructions != null ? tr('Previous') : '—', tr('Updated'), field: 'instructions'));
    }
    return out;
  }

  Future<void> _save(bool mustNotify) async {
    final p = plan!;
    final n = int.tryParse(limit);
    final minimum = p.participantCount > 2 ? p.participantCount : 2;
    if (n == null || n < minimum) {
      setState(() => error = tr('The limit can’t be lower than the {participantCount} people who already joined.', {'participantCount': p.participantCount}));
      return;
    }
    if (meet.trim().isEmpty) {
      setState(() => error = tr('Add a public meeting point.'));
      return;
    }
    final toast = useToast(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await PlansApi.updateDetails(p.id, {
        'startAt': start?.toUtc().toIso8601String(),
        'meetingPoint': meet.trim(),
        'participantLimit': n,
        'instructions': instructions.trim(),
        'notify': notify || mustNotify,
      });
      toast(notify || mustNotify ? tr('Saved. Participants were notified.') : tr('Saved.'));
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
    final p = plan;
    if (p == null) {
      return Screen(children: [
        Header(kicker: tr('EDIT'), title: tr('Edit details')),
        if (error != null) Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!) else const Loading(),
      ]);
    }
    final ch = changes;
    // Time and location changes always notify — participants must never miss them.
    final mustNotify = ch.any((c) => c.field == 'startAt' || c.field == 'meetingPoint');
    return Screen(bottom: true, children: [
      Header(kicker: p.title.toUpperCase(), title: tr('Edit details')),
      Padding(padding: const EdgeInsets.only(bottom: 16), child: Txt(tr('Changes update the Plan for everyone. Participants see exactly what changed.'))),
      DateField(label: tr('Date & time'), value: start, onChange: (d) => setState(() => start = d), minimumDate: DateTime.now()),
      Field(label: tr('Meeting point'), value: meet, onChanged: (t) => setState(() => meet = t), hint: tr('Public places only.')),
      Field(
        label: tr('Participant limit'),
        value: limit,
        onChanged: (t) => setState(() => limit = t),
        formatters: [digitsOnly],
        keyboardType: TextInputType.number,
      ),
      Field(
        label: tr('Instructions for participants'),
        optional: true,
        value: instructions,
        onChanged: (t) => setState(() => instructions = t),
        multiline: true,
        maxLength: 600,
      ),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: ListRow(
          first: true,
          label: tr('Notify participants'),
          sub: tr('On for time and location changes. They get one notification with what changed.'),
          right: Switch(value: notify || mustNotify, disabled: mustNotify, onChange: (v) => setState(() => notify = v), label: tr('Notify participants')),
        ),
      ),
      if (ch.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Diff(ch)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!)),
      Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Save changes'), disabled: ch.isEmpty, loading: busy, onPress: () => _save(mustNotify))),
    ]);
  }
}

// ---------- Announcement ----------

class AnnouncementScreen extends StatefulWidget {
  final int id;
  const AnnouncementScreen({super.key, required this.id});
  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> with FocusData<AnnouncementScreen, PlanDetail> {
  String title = '';
  String body = '';
  bool busy = false;
  String? err;

  @override
  Future<PlanDetail> load() => PlansApi.get(widget.id);

  Future<void> _publish() async {
    if (title.trim().length < 3) return setState(() => err = tr('Add a short headline.'));
    if (body.trim().length < 5) return setState(() => err = tr('Add the message participants need to know.'));
    final toast = useToast(context);
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await PlansApi.announce(widget.id, title.trim(), body.trim());
      toast(tr('Announcement published and pinned.'));
      Nav.back();
    } catch (e) {
      if (mounted) setState(() => err = e is ApiError ? e.message : tr('Couldn’t publish. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final plan = data;
    final reach = plan != null ? '${plan.participantCount - 1 < 0 ? 0 : plan.participantCount - 1} participants' : 'participants';
    return Screen(bottom: true, children: [
      Header(kicker: plan?.title.toUpperCase(), title: tr('Announcement')),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Txt(tr('Announcements are pinned in the Plan Group and sent to every participant. Use them for important Plan information.')),
      ),
      Field(label: tr('Headline'), value: title, onChanged: (t) => setState(() => title = t), maxLength: 60, placeholder: tr('Meeting point update')),
      Field(
        label: tr('Message'),
        value: body,
        onChanged: (t) => setState(() => body = t),
        multiline: true,
        maxLength: 500,
        hint: '${body.length}/500',
        placeholder: tr('The group will meet at the west entrance at 9:45 AM.'),
      ),
      if (err != null) Banner(icon: 'alert-circle', tone: PillTone.bad, title: err!),
      SectionTitle(tr('Preview')),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFE0EDF2), borderRadius: BorderRadius.circular(16)),
        child: Col(gap: 4, [
          Text(tr('IMPORTANT ANNOUNCEMENT'), style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: Color(0xFF2B5C74))),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: title.isNotEmpty ? title : tr('Headline'), style: const TextStyle(fontFamily: Fonts.bodyBold)),
              TextSpan(text: ' ${body.isNotEmpty ? body : tr('Your message appears here.')}'),
            ]),
            style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, height: 19 / 13, color: AppColors.ink),
          ),
          Txt('${plan?.host.name ?? ''} · ${plan?.host.subtitle ?? ''} ${tr('· Pinned')}', variant: TV.caption),
        ]),
      ),
      Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const IconTile('bell', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(tr('Important update in {plan}', {'plan': plan?.title}), variant: TV.bodyStrong),
              Txt(tr('How participants see the notification · {reach}', {'reach': reach}), variant: TV.small),
            ]),
          ),
        ]),
      ),
      Padding(padding: const EdgeInsets.only(top: 18), child: Button(tr('Publish announcement'), loading: busy, onPress: _publish)),
    ]);
  }
}
