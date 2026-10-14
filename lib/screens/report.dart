import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../widgets/ui.dart';

const _person = [
  'Harassment or unwanted behavior', 'Spam or scams', 'Threatening behavior', 'Inappropriate or sexual content', 'Fake or misleading identity',
  'Impersonation', 'Unsafe or suspicious activity', 'Discrimination or hateful behavior', 'Something else',
];
const _message = [
  'Harassment or unwanted behavior', 'Spam or scams', 'Threatening behavior', 'Inappropriate or sexual content', 'Unsafe or suspicious activity',
  'Discrimination or hateful behavior', 'Something else',
];

const _reasons = <String, List<String>>{
  'PROFILE': _person,
  'PARTICIPANT': _person,
  'MESSAGE': _message,
  'CONVERSATION': _message,
  'EVENT': ['Misleading event', 'Unsafe activity', 'Spam or scam', 'Inappropriate content', 'Organizer identity concern', 'Something else'],
  'PLAN': ['Misleading information', 'Suspicious activity', 'Unsafe activity', 'Spam', 'Inappropriate content', 'Something else'],
  'GROUP': ['Harassment or unwanted behavior', 'Spam or scams', 'Inappropriate or sexual content', 'Unsafe or suspicious activity', 'Something else'],
  'ORGANIZER': ['Fake or misleading identity', 'Impersonation', 'Misleading information', 'Spam or scams', 'Something else'],
  'PROBLEM': ['A safety concern', 'Something isn’t working', 'Something else'],
};

// Whole titles (not noun substitution) so each language can order words naturally.
const _title = {
  'PROFILE': 'Report profile', 'PARTICIPANT': 'Report participant', 'MESSAGE': 'Report message', 'CONVERSATION': 'Report conversation',
  'EVENT': 'Report event', 'PLAN': 'Report Plan', 'GROUP': 'Report group', 'ORGANIZER': 'Report organizer', 'PROBLEM': 'Report a problem',
};

class ReportFlowScreen extends StatefulWidget {
  final Map<String, String> params;
  const ReportFlowScreen({super.key, required this.params});
  @override
  State<ReportFlowScreen> createState() => _ReportFlowScreenState();
}

class _ReportFlowScreenState extends State<ReportFlowScreen> {
  String step = 'reason'; // reason | form | done | error | offline | duplicate
  String? reason;
  String details = '';
  bool blockToo = false;
  bool blocked = false;
  bool busy = false;
  int? existingId;

  String _p(String k) => widget.params[k] ?? '';
  String get type => _reasons.containsKey(_p('targetType')) ? _p('targetType') : 'PROBLEM';
  int? get personId => int.tryParse(_p('personId'));
  String get first => _p('personName').isNotEmpty ? _p('personName') : tr('this person');

  Future<void> _submit() async {
    if (reason == null) return;
    setState(() => busy = true);
    try {
      await SafetyApi.report(
        targetType: type,
        targetId: int.tryParse(_p('targetId')),
        reason: reason!,
        details: details.trim().isEmpty ? null : details.trim(),
        blockUserId: blockToo ? personId : null,
      );
      blocked = blockToo;
      AnalyticsApi.track('report_submitted', {'type': type, 'blocked': blockToo});
      setState(() => step = 'done');
    } catch (e) {
      if (e is ApiError && e.code == 'DUPLICATE_REPORT') {
        setState(() {
          existingId = e.existingId;
          step = 'duplicate';
        });
      } else {
        setState(() => step = e is ApiError && e.isNetwork ? 'offline' : 'error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _cancel() => goBack();

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final pid = personId;
    final quote = _p('quote');
    final sub = _p('sub');

    final context0 = (step == 'reason' || step == 'form')
        ? Semantics(
            label: tr('What you are reporting'),
            container: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  if (pid != null)
                    Avatar(name: _p('personName').isNotEmpty ? _p('personName') : _p('title'), id: pid, size: 40)
                  else
                    IconTile(type == 'MESSAGE' || type == 'CONVERSATION' ? 'message-circle' : (type == 'PLAN' || type == 'EVENT' ? 'calendar' : 'flag')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Txt(_p('title'), variant: TV.bodyStrong),
                      if (sub.isNotEmpty) Txt(sub, variant: TV.small),
                    ]),
                  ),
                ]),
                if (quote.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
                    child: Text('“$quote”', style: const TextStyle(fontFamily: Fonts.body, fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.inkSoft)),
                  ),
              ]),
            ),
          )
        : null;

    return Screen(bottom: true, children: [
      Header(
        title: tr(_title[type]!),
        center: true,
        onBack: step == 'form' ? () => setState(() => step = 'reason') : _cancel,
        right: IconBtn('x', label: tr('Cancel report'), onPress: _cancel),
      ),
      ?context0,
      if (step == 'reason') ...[
        Padding(padding: const EdgeInsets.only(top: 18), child: Txt(tr('What would you like to report?'), variant: TV.title)),
        Padding(padding: const EdgeInsets.only(bottom: 14), child: Txt(tr('Choose the closest option.'))),
        RadioCards<String>(
          label: tr('Report reason'),
          options: _reasons[type]!.map((r) => RadioOption(r, tr(r))).toList(),
          value: reason,
          onChange: (v) => setState(() => reason = v),
        ),
        Padding(padding: const EdgeInsets.only(top: 18), child: Button(tr('Continue'), disabled: reason == null, onPress: () => setState(() => step = 'form'))),
      ],
      if (step == 'form') ...[
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Text(reason != null ? tr(reason!) : '', style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 13, color: AppColors.brandDark)),
            ),
            Button(tr('Change'), kind: BK.text, compact: true, onPress: () => setState(() => step = 'reason')),
          ]),
        ),
        Field(
          label: tr('Tell us more'),
          optional: true,
          hint: '${details.length}/1000 · Additional context can help us review this report.',
          value: details,
          onChanged: (t) => setState(() => details = t),
          multiline: true,
          maxLength: 1000,
          placeholder: tr('What happened? A sentence is enough.'),
        ),
        if (pid != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
            child: ListRow(
              first: true,
              label: tr('Block {first} too', {'first': first}),
              sub: tr('Reporting and blocking are separate. Off unless you choose.'),
              right: Switch(value: blockToo, onChange: (v) => setState(() => blockToo = v), label: tr('Block {first} after reporting', {'first': first})),
            ),
          ),
        Note(
          '${tr('Reports are handled privately.')} ${pid != null ? tr('{first} won’t be told who reported them.', {'first': first}) : tr('The creator won’t see who reported this.')}',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Button(busy ? tr('Submitting…') : tr('Submit report'), kind: BK.dangerSolid, loading: busy, onPress: _submit),
        ),
      ],
      if (step == 'done')
        StateBlock(
          icon: 'check',
          title: tr('Report submitted'),
          body: tr('Thanks for letting us know. We’ll review the report and take appropriate action when needed.{v}', {
            'v': blocked ? tr(' You also blocked {first} — they can’t message you or see your Plans.', {'first': first}) : '',
          }),
          actions: [
            StateAction(tr('Done'), _cancel),
            if (pid != null && !blocked)
              StateAction(tr('Block {first}', {'first': first}), () async {
                await SafetyApi.block(pid);
                if (mounted) setState(() => blocked = true);
              }, BK.secondary),
            StateAction(tr('Go to Safety Center'), () => Nav.replace('/safety'), BK.text),
          ],
        ),
      if (step == 'error')
        StateBlock(
          icon: 'refresh-cw',
          tone: PillTone.bad,
          title: tr('Your report couldn’t be submitted'),
          body: tr('Nothing was sent. Your answers are saved — try again.'),
          actions: [StateAction(tr('Try again'), _submit)],
        ),
      if (step == 'offline')
        StateBlock(
          icon: 'wifi-off',
          tone: PillTone.neutral,
          title: tr('You’re offline'),
          body: tr('Connect to the internet to submit this report. Nothing has been sent yet.'),
          actions: [StateAction(tr('Try again'), _submit)],
        ),
      if (step == 'duplicate')
        StateBlock(
          icon: 'flag',
          tone: PillTone.neutral,
          title: tr('You’ve already reported this'),
          body: tr('Your earlier report is still open, so there’s no need to send another.'),
          actions: [
            if (existingId != null) StateAction(tr('View report status'), () => Nav.replace('/safety/reports/$existingId')),
            StateAction(tr('Close'), _cancel, BK.secondary),
          ],
        ),
      if (step == 'done') Txt(tr('If you are in immediate danger, call 112.'), variant: TV.small, align: TextAlign.center),
    ]);
  }
}
