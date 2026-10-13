import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;

import '../api/types.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../util/format.dart';
import 'sheet.dart';
import 'ui.dart';

/// What the explainer sheet shows: one signal, the overview, or the "status unavailable" note.
sealed class Explain {
  const Explain();
}

class ExplainSignal extends Explain {
  final Signal signal;
  const ExplainSignal(this.signal);
}

class ExplainAbout extends Explain {
  const ExplainAbout();
}

class ExplainUnavailable extends Explain {
  const ExplainUnavailable();
}

const _signalIcon = <String, IconName>{
  'IDENTITY': 'shield', 'ORGANIZER': 'shield', 'OFFICIAL': 'calendar', 'PHONE': 'check', 'EMAIL': 'check',
};

String _means(Signal s, [String? n]) {
  switch (s) {
    case 'IDENTITY':
      return n != null
          ? tr('{name} completed the identity verification process supported by Plans. The ID matched the name and age range on the profile.', {'name': n})
          : tr('This person completed the identity verification process supported by Plans. The ID matched the name and age range on the profile.');
    case 'PHONE':
      return n != null
          ? tr('{name} confirmed ownership of a phone number with a one-time code. The number itself is never shown.', {'name': n})
          : tr('They confirmed ownership of a phone number with a one-time code. The number itself is never shown.');
    case 'EMAIL':
      return n != null
          ? tr('{name} confirmed ownership of an email address. The address itself is never shown.', {'name': n})
          : tr('They confirmed ownership of an email address. The address itself is never shown.');
    case 'ORGANIZER':
      return n != null
          ? tr('{name} completed the verification required for this organizer type: name, official contact domain and public presence were checked.', {'name': n})
          : tr('This organizer completed the verification required for this organizer type: name, official contact domain and public presence were checked.');
    default:
      return tr('This event is represented by a verified organizer, through their official organizer account.');
  }
}

const _not = {
  'IDENTITY': 'Verification doesn’t guarantee someone’s behaviour, intentions or safety.',
  'PHONE': 'It doesn’t confirm who someone is, or anything about their behaviour.',
  'EMAIL': 'It doesn’t confirm who someone is, or anything about their behaviour.',
  'ORGANIZER': 'Verification doesn’t guarantee the quality, safety or outcome of an event, or vouch for each attendee.',
  'OFFICIAL': 'It doesn’t verify every attendee, or guarantee safety at the event.',
};

String signalMeaning(Signal s) => '${_means(s).split('. ').first}.';

/// Tappable factual signals ("Identity verified", "Phone verified").
/// Shows nothing when status is unavailable rather than a stale signal.
class TrustSignals extends StatelessWidget {
  final List<Signal> signals;
  final String? name;
  final bool unavailable;
  final bool compact;
  const TrustSignals({super.key, required this.signals, this.name, this.unavailable = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final sorted = sortSignals(signals);
    final shown = compact ? sorted.take(1).toList() : sorted;
    return Semantics(
      label: tr('Trust signals'),
      container: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: unavailable
            ? [
                Pill(tr('Verification status unavailable'),
                    icon: 'clock', tone: PillTone.neutral, onPress: () => showSignalExplainer(context, const ExplainUnavailable(), name: name)),
              ]
            : shown
                .map((s) => Pill(
                      signalLabel(s),
                      icon: _signalIcon[s] ?? 'check',
                      tone: s == 'IDENTITY' || s == 'ORGANIZER' || s == 'OFFICIAL' ? PillTone.ok : PillTone.neutral,
                      onPress: () => showSignalExplainer(context, ExplainSignal(s), name: name),
                      a11yLabel: tr('{v}. Learn what this means', {'v': signalLabel(s)}),
                    ))
                .toList(),
      ),
    );
  }
}

Future<void> showSignalExplainer(BuildContext context, Explain explain, {String? name}) {
  var about = false;
  return showSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final current = about ? const ExplainAbout() : explain;
      void close() => Navigator.of(ctx).pop();

      var kicker = tr('TRUST SIGNAL');
      var title = '';
      IconName icon = 'shield';
      var sections = <(String, String)>[];
      var tiers = false;

      switch (current) {
        case ExplainSignal(:final signal):
          title = signalLabel(signal);
          icon = _signalIcon[signal] ?? 'shield';
          sections = [(tr('What this means'), _means(signal, name)), (tr('What this does not mean'), tr(_not[signal] ?? ''))];
        case ExplainUnavailable():
          kicker = tr('VERIFICATION STATUS');
          title = tr('Status unavailable');
          icon = 'clock';
          final n = name ?? tr('this person');
          sections = [
            (tr('What’s happening'), tr('We couldn’t confirm {n}’s verification status right now, so we’re not showing any signals rather than an out-of-date one.', {'n': n})),
            (tr('What it doesn’t mean'), tr('It doesn’t mean {n} is unverified or untrustworthy.', {'n': n})),
          ];
        case ExplainAbout():
          kicker = 'TRUST';
          title = tr('About trust signals');
          sections = [(tr('Why do I see these signals?'), tr('They give context about information that has been verified, or that you and another person share — like a Plan or an event.'))];
          tiers = true;
      }

      return Semantics(
        label: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              IconTile(icon, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Txt(kicker, variant: TV.kicker),
                  Txt(title, variant: TV.heading),
                ]),
              ),
            ]),
          ),
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Txt(s.$1, variant: TV.bodyStrong),
                const SizedBox(height: 3),
                Txt(s.$2),
              ]),
            ),
          if (tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Col(gap: 10, [
                for (final (label, items) in [
                  (tr('STRONG FACTUAL'), [tr('Identity verified'), tr('Organizer verified'), tr('Official event')]),
                  ('CONTACT', [tr('Phone verified'), tr('Email verified')]),
                ])
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Txt(label, variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: items.map((i) => Pill(i)).toList()),
                  ]),
                Txt(tr('Shared context — a shared Plan, event, destination or mutual connection — is shown separately and isn’t verification.'), variant: TV.small),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(12)),
                  child: Txt.rich(
                    [
                      bold('${tr('Important.')} ', color: AppColors.brandDark),
                      TextSpan(text: tr('Plans never shows trust or safety scores, ratings or rankings. Not being verified is common and shown neutrally.')),
                    ],
                    variant: TV.small,
                    style: const TextStyle(color: AppColors.brandDark),
                  ),
                ),
              ]),
            ),
          Row(children: [
            Expanded(child: Button(tr('Got it'), onPress: close)),
            if (current is! ExplainAbout) ...[
              const SizedBox(width: 8),
              Expanded(child: Button(tr('About trust signals'), kind: BK.secondary, onPress: () => setState(() => about = true))),
            ],
          ]),
          if (current is ExplainSignal && (current.signal == 'IDENTITY' || current.signal == 'ORGANIZER'))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Button(tr('Report a fake identity'), kind: BK.text, icon: 'flag', onPress: () {
                close();
                Nav.push('/safety');
              }),
            ),
        ]),
      );
    }),
  );
}

class SignalIcon extends StatelessWidget {
  final Signal signal;
  const SignalIcon(this.signal, {super.key});
  @override
  Widget build(BuildContext context) => FIcon(_signalIcon[signal] ?? 'check', size: 12, color: AppColors.brand);
}
