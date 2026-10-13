import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/types.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../util/format.dart';
import '../util/misc.dart';
import 'sheet.dart';
import 'ui.dart';

// ---------- Composer ----------

const _maxMessage = 2000;

class Composer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final String? placeholder;
  final String? note;
  const Composer({super.key, required this.onSend, this.placeholder, this.note});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _c = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ?? tr('Write a message…');
    final empty = _c.text.trim().isEmpty;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                label: placeholder,
                child: TextField(
                  controller: _c,
                  minLines: 1,
                  maxLines: null,
                  maxLength: _maxMessage,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontFamily: Fonts.body, fontSize: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: placeholder,
                    hintStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 14, color: Color(0xFF8A9893)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onPress: empty ? null : _send,
            disabled: empty,
            label: tr('Send'),
            focusRadius: BorderRadius.circular(22),
            builder: (_, _, _) => Opacity(
              opacity: empty ? 0.4 : 1,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                child: const FIcon('arrow-right', size: 18, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
      if (widget.note != null)
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.only(bottom: 6),
          child: Txt(widget.note, variant: TV.caption, align: TextAlign.center),
        ),
    ]);
  }
}

// ---------- Consent checks ----------

class ConsentState {
  final bool terms;
  final bool adult;
  const ConsentState({this.terms = false, this.adult = false});
  ConsentState copyWith({bool? terms, bool? adult}) => ConsentState(terms: terms ?? this.terms, adult: adult ?? this.adult);
}

/// The two agreements needed to create an account, as separate unticked boxes (no bundling, no pre-ticking).
/// Policy names are links that open the full text first.
class ConsentChecks extends StatelessWidget {
  final ConsentState value;
  final ValueChanged<ConsentState> onChange;
  final bool error;
  const ConsentChecks({super.key, required this.value, required this.onChange, this.error = false});

  void _open(String slug) => Nav.push('/legal/$slug');

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    const link = TextStyle(fontFamily: Fonts.bodyBold, color: AppColors.brand, decoration: TextDecoration.underline);
    const readLink = TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: AppColors.brand);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Col(gap: 10, [
        _Check(
          checked: value.terms,
          onToggle: () => onChange(value.copyWith(terms: !value.terms)),
          error: error && !value.terms,
          a11y: tr('I agree to the Terms of service and the Privacy policy'),
          spans: [
            TextSpan(text: tr('I agree to the ')),
            TextSpan(text: tr('Terms of service'), style: link, recognizer: TapGestureRecognizer()..onTap = () => _open('terms')),
            TextSpan(text: tr(' and the ')),
            TextSpan(text: tr('Privacy policy'), style: link, recognizer: TapGestureRecognizer()..onTap = () => _open('privacy')),
            TextSpan(text: tr('.')),
          ],
        ),
        // The links inside the checkbox can't be reached separately by screen readers; these can.
        Transform.translate(
          offset: const Offset(0, -2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(spacing: 8, children: [
              Pressable(onPress: () => _open('terms'), link: true, label: tr('Read the Terms'),
                  builder: (_, _, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(tr('Read the Terms'), style: readLink))),
              const ExcludeSemantics(child: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('·', style: TextStyle(color: AppColors.inkSoft)))),
              Pressable(onPress: () => _open('privacy'), link: true, label: tr('Read the Privacy policy'),
                  builder: (_, _, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(tr('Read the Privacy policy'), style: readLink))),
            ]),
          ),
        ),
        _Check(
          checked: value.adult,
          onToggle: () => onChange(value.copyWith(adult: !value.adult)),
          error: error && !value.adult,
          a11y: tr('I confirm I am 18 or older'),
          spans: [TextSpan(text: tr('I confirm I’m 18 or older. Plans is for adults only.'))],
        ),
        if (error && !(value.terms && value.adult))
          Semantics(
            liveRegion: true,
            child: Text(tr('Tick both boxes to create an account.'),
                style: const TextStyle(fontFamily: Fonts.bodySemi, fontSize: 12, color: AppColors.dangerText)),
          ),
      ]),
    );
  }
}

class _Check extends StatelessWidget {
  final bool checked;
  final VoidCallback onToggle;
  final bool error;
  final String a11y;
  final List<InlineSpan> spans;
  const _Check({required this.checked, required this.onToggle, required this.error, required this.a11y, required this.spans});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPress: onToggle,
      checked: checked,
      label: a11y,
      focusRadius: BorderRadius.circular(12),
      builder: (_, _, _) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: GlassTokens.fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: GlassTokens.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checked ? AppColors.brand : Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: error ? AppColors.dangerText : (checked ? AppColors.brand : AppColors.inputBorder), width: 2),
            ),
            child: checked ? const FIcon('check', size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(TextSpan(children: spans),
                style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, height: 19 / 13, color: AppColors.inkSoft)),
          ),
        ]),
      ),
    );
  }
}

// ---------- Date field ----------

DateTime _defaultDate() {
  final d = DateTime.now().add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, 18);
}

/// Date + time picker: native dialogs on Android, a bottom sheet with the inline picker on iOS.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChange;
  final bool optional;
  final String? error;
  final DateTime? minimumDate;
  const DateField({super.key, required this.label, required this.value, required this.onChange, this.optional = false, this.error, this.minimumDate});

  Future<void> _open(BuildContext context) async {
    final base = value ?? _defaultDate();
    if (Platform.isIOS) {
      var draft = base;
      await showSheet<void>(
        context,
        label: label,
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.dateAndTime,
              initialDateTime: base,
              minimumDate: minimumDate != null && minimumDate!.isBefore(base) ? minimumDate : null,
              onDateTimeChanged: (d) => draft = d,
            ),
          ),
          const SizedBox(height: 8),
          Button(tr('Done'), onPress: () {
            onChange(draft);
            Navigator.of(ctx).pop();
          }),
        ]),
      );
      return;
    }
    final first = minimumDate ?? DateTime(2000);
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(first) ? first : base,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    onChange(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final text = value != null ? planDate(value!.toUtc().toIso8601String()) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (optional) TextSpan(text: ' ${tr('(optional)')}', style: const TextStyle(fontFamily: Fonts.body, color: AppColors.inkSoft)),
            ]),
            style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 13, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 6),
        Pressable(
          onPress: () => _open(context),
          label: '$label: ${text ?? tr('not set')}',
          builder: (_, _, _) => Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: error != null ? AppColors.danger : AppColors.line),
            ),
            child: Row(children: [
              const FIcon('calendar', size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text ?? tr('Choose date and time'),
                    style: TextStyle(fontFamily: Fonts.body, fontSize: 15, color: value == null ? const Color(0xFF8A9893) : AppColors.ink)),
              ),
              if (value != null && optional)
                Pressable(
                  onPress: () => onChange(null),
                  label: tr('Clear {label}', {'label': label}),
                  builder: (_, _, _) => const Padding(padding: EdgeInsets.all(10), child: FIcon('x', size: 16, color: AppColors.inkSoft)),
                ),
            ]),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error!, style: const TextStyle(fontFamily: Fonts.bodySemi, fontSize: 12, color: AppColors.danger)),
          ),
      ]),
    );
  }
}

// ---------- Language picker ----------

/// Compact language switch for screens shown before sign-in. Names are always in their own script.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Semantics(
      label: 'Language / भाषा / ಭಾಷೆ',
      container: true,
      child: Start(
        Wrap(
          spacing: 6,
          children: languages.map((l) {
            final on = l.value == i18n.lang;
            return Pressable(
              onPress: () => i18n.setLang(l.value),
              checked: on,
              inMutuallyExclusiveGroup: true,
              label: l.secondary ? '${l.label} (${l.english}, secondary)' : '${l.label} (${l.english})',
              focusRadius: BorderRadius.circular(999),
              builder: (_, _, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? AppColors.brandPale : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: on ? AppColors.brand : AppColors.line),
                ),
                child: Text(l.label, style: TextStyle(fontFamily: Fonts.bodySemi, fontSize: 13, color: on ? AppColors.brandDark : AppColors.inkSoft)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------- Markdown ----------

const _mdH = TextStyle(fontFamily: Fonts.display, color: AppColors.ink, letterSpacing: -0.4);
const _mdP = TextStyle(fontFamily: Fonts.body, fontSize: 15, height: 23 / 15, color: AppColors.inkSoft);

/// Just enough Markdown for policy pages edited in the Admin Console: #, ##, ### headings, paragraphs, "- " lists,
/// **bold**, _italic_ and [links](https://…). Headings are marked as headers so screen readers can jump between them.
class Markdown extends StatelessWidget {
  final String text;
  const Markdown(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final blocks = text.replaceAll('\r', '').split(RegExp(r'\n{2,}'));
    final out = <Widget>[];
    for (final block in blocks) {
      final b = block.trim();
      if (b.isEmpty) continue;
      final h = RegExp(r'^(#{1,3})\s+([\s\S]*)$').firstMatch(b);
      if (h != null) {
        final level = h.group(1)!.length;
        final style = _mdH.copyWith(
          fontSize: level == 1 ? 24 : (level == 2 ? 18 : 15),
          height: level == 1 ? 29 / 24 : (level == 2 ? 23 / 18 : 20 / 15),
        );
        out.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 4 : (level == 2 ? 10 : 6)),
          child: Semantics(header: true, child: Text.rich(TextSpan(children: _inline(h.group(2)!)), style: style)),
        ));
        continue;
      }
      final lines = b.split('\n');
      final bullet = RegExp(r'^\s*[-*]\s+');
      if (lines.every((l) => bullet.hasMatch(l))) {
        out.add(Col(
          gap: 8,
          lines
              .map((l) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const ExcludeSemantics(child: Text('•', style: _mdP)),
                    const SizedBox(width: 10),
                    Expanded(child: Text.rich(TextSpan(children: _inline(l.replaceFirst(bullet, ''))), style: _mdP)),
                  ]))
              .toList(),
        ));
        continue;
      }
      out.add(Text.rich(TextSpan(children: _inline(lines.join(' '))), style: _mdP));
    }
    return Col(gap: 12, out);
  }

  static void _openLink(String url) {
    if (url.startsWith('mailto:') || url.startsWith('tel:')) {
      launchUrl(Uri.parse(url));
    } else if (url.startsWith('https://')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    }
  }

  /// Bold, italic and links inside a line.
  static List<InlineSpan> _inline(String s) {
    final out = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|\[(.+?)\]\(((?:https:\/\/|mailto:|tel:)[^)\s]+)\)');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        out.add(TextSpan(text: m.group(1), style: const TextStyle(fontFamily: Fonts.bodyBold, color: AppColors.ink)));
      } else if (m.group(2) != null) {
        out.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        final url = m.group(4)!;
        out.add(TextSpan(
          text: m.group(3),
          style: const TextStyle(fontFamily: Fonts.bodyBold, color: AppColors.brand, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => _openLink(url),
        ));
      }
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }
}

// ---------- Plan cover & cards ----------

/// Cover art drawn by the app: a gradient and an icon per category. Nothing is licensed from a third party,
/// so there is no image rights question. A host’s own uploaded cover (coverImageUrl) is shown instead when set.
const _art = <String, (List<Color>, IconName)>{
  'travel': ([Color(0xFF1F8A8A), Color(0xFF0D4D5C)], 'map'),
  'trek': ([Color(0xFF3D8A4F), Color(0xFF1B4D33)], 'triangle'),
  'photography': ([Color(0xFF6B5BC9), Color(0xFF33296E)], 'camera'),
  'concert': ([Color(0xFFB8487A), Color(0xFF5C1F45)], 'music'),
  'event': ([Color(0xFFC06A2B), Color(0xFF6B3312)], 'star'),
  'sports': ([Color(0xFF2F7FC1), Color(0xFF163F6B)], 'activity'),
  'gaming': ([Color(0xFF7046B8), Color(0xFF2E1D5E)], 'monitor'),
  'college': ([Color(0xFF3C6FB0), Color(0xFF1C355E)], 'book-open'),
  'hackathon': ([Color(0xFF2B7A6B), Color(0xFF123D38)], 'code'),
  'networking': ([Color(0xFF4A6A8C), Color(0xFF22344A)], 'users'),
  'food': ([Color(0xFFC4572D), Color(0xFF6E2814)], 'coffee'),
  'movie': ([Color(0xFF8A3F5C), Color(0xFF3E1A2B)], 'film'),
};
const _fallbackArt = ([Color(0xFF178066), Color(0xFF0C4F40)], 'calendar');

class PlanCover extends StatelessWidget {
  final String category;
  final String? coverImageUrl;
  final double iconSize;
  const PlanCover({super.key, required this.category, this.coverImageUrl, this.iconSize = 64});

  @override
  Widget build(BuildContext context) {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) {
      return Positioned.fill(
        child: Semantics(
          image: true,
          label: tr('Cover photo for this {category} Plan', {'category': categoryLabel(category)}),
          child: Image.network(coverImageUrl!, fit: BoxFit.cover),
        ),
      );
    }
    final art = _art[category.toLowerCase()] ?? _fallbackArt;
    // Decorative: the category is also written on the card, so screen readers skip the art.
    return Positioned.fill(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) => Stack(children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: art.$1))),
            ),
            _circle(c.maxWidth * 0.88, c.maxHeight * 0.18, 70, const Color.fromRGBO(255, 255, 255, 0.09)),
            _circle(c.maxWidth * 0.10, c.maxHeight * 1.10, 90, const Color.fromRGBO(255, 255, 255, 0.07)),
            _circle(c.maxWidth * 0.70, c.maxHeight * 0.95, 34, const Color.fromRGBO(223, 240, 96, 0.22)),
            Positioned(
              right: 18,
              bottom: 12,
              child: Transform.rotate(angle: -8 * 3.1415926535 / 180, child: FIcon(art.$2, size: iconSize, color: const Color.fromRGBO(255, 255, 255, 0.28))),
            ),
          ]),
        ),
      ),
    );
  }

  static Widget _circle(double cx, double cy, double r, Color color) => Positioned(
        left: cx - r,
        top: cy - r,
        child: Container(width: r * 2, height: r * 2, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );
}

/// Home "Nearby plans" card: cover, category, Official event, why it's relevant, host.
class PlanCard extends StatelessWidget {
  final PlanSummary plan;
  final VoidCallback onPress;
  const PlanCard({super.key, required this.plan, required this.onPress});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final sig = topSignal(plan.host.signals);
    return Pressable(
      onPress: onPress,
      scale: 0.98,
      focusRadius: BorderRadius.circular(24),
      label: '${plan.title}, ${categoryLabel(plan.category)}, ${planDate(plan.startAt, plan.endAt)}, ${plan.area}${plan.official ? ', ${tr('Official event')}' : ''}',
      builder: (_, _, _) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.9)),
          boxShadow: cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 138,
            child: Stack(children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.brandDark)),
              PlanCover(category: plan.category, coverImageUrl: plan.coverImageUrl, iconSize: 58),
              const Positioned.fill(child: ColoredBox(color: Color.fromRGBO(15, 25, 23, 0.12))),
              Positioned(
                left: 12,
                top: 12,
                child: Row(children: [
                  _catBadge(categoryLabel(plan.category)),
                  if (plan.official) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const FIcon('check', size: 11, color: AppColors.ink),
                        const SizedBox(width: 4),
                        Text(tr('Official event'), style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, color: AppColors.ink)),
                      ]),
                    ),
                  ],
                ]),
              ),
              if (plan.why != null && plan.why!.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const FIcon('star', size: 10, color: AppColors.ink),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(plan.why!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: AppColors.ink)),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Col(gap: 6, [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Txt(plan.title, variant: TV.heading, style: const TextStyle(fontSize: 17), maxLines: 2)),
                if (plan.status != 'ACTIVE') ...[const SizedBox(width: 8), PlanStatusPill(plan.status)],
              ]),
              _meta('calendar', planDate(plan.startAt, plan.endAt)),
              _meta('map-pin', tr('{area} · approximate', {'area': plan.area})),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Avatar(name: plan.host.name, photoUrl: plan.host.photoUrl, id: plan.host.id, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: plan.host.name),
                        if (sig != null) TextSpan(text: ' · $sig', style: const TextStyle(fontFamily: Fonts.body, color: AppColors.inkSoft)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: AppColors.ink),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _meta(IconName icon, String text) => Row(children: [
        FIcon(icon, size: 13, color: AppColors.inkSoft),
        const SizedBox(width: 7),
        Expanded(child: Txt(text, variant: TV.small, maxLines: 1)),
      ]);
}

Widget _catBadge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: const Color.fromRGBO(15, 25, 23, 0.45), borderRadius: BorderRadius.circular(999)),
      child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: Fonts.bodyBold, fontSize: 10, letterSpacing: 0.8)),
    );

Widget categoryBadge(String label) => _catBadge(label);

/// Compact list row: organizer upcoming list, My plans, search results.
class PlanRow extends StatelessWidget {
  final PlanSummary plan;
  final VoidCallback onPress;
  final bool first;
  const PlanRow({super.key, required this.plan, required this.onPress, this.first = false});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Pressable(
      onPress: onPress,
      focusRadius: BorderRadius.zero,
      builder: (_, pressed, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pressed ? AppColors.paper : null,
          border: first ? null : const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(12)),
            child: const FIcon('calendar', size: 17, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Col(gap: 2, [
              Txt(plan.title, variant: TV.bodyStrong, maxLines: 1),
              Txt(
                '${planDate(plan.startAt, plan.endAt)} · ${plan.area} · ${tr('{n} of {limit}', {'n': plan.participantCount, 'limit': plan.participantLimit})}',
                variant: TV.small,
                maxLines: 1,
              ),
              if (plan.official)
                Row(children: [
                  const FIcon('check', size: 11, color: AppColors.brand),
                  const SizedBox(width: 4),
                  Txt(tr('Official event'), variant: TV.caption, style: const TextStyle(color: AppColors.brand)),
                ]),
            ]),
          ),
          const SizedBox(width: 12),
          if (plan.status != 'ACTIVE') PlanStatusPill(plan.status) else const FIcon('chevron-right', size: 16, color: AppColors.inkSoft),
        ]),
      ),
    );
  }
}

// ---------- Profile bits ----------

/// "YOU’RE BOTH JOINING · Weekend Photography Walk" card, used on requests, profiles and chats.
class SharedPlanCard extends StatelessWidget {
  final SharedPlanRef plan;
  final VoidCallback onPress;
  final IconName icon;
  const SharedPlanCard({super.key, required this.plan, required this.onPress, this.icon = 'calendar'});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPress: onPress,
      label: '${plan.label}: ${plan.title}, ${plan.when}',
      focusRadius: BorderRadius.circular(18),
      builder: (_, pressed, _) => Opacity(
        opacity: pressed ? 0.92 : 1,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            IconTile(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.label, style: _pbKicker),
                Padding(padding: const EdgeInsets.only(top: 1), child: Text(plan.title, style: _pbTitle)),
                Padding(padding: const EdgeInsets.only(top: 1), child: Text(plan.when, style: _pbSub)),
              ]),
            ),
            const FIcon('arrow-right', size: 16, color: AppColors.brand),
          ]),
        ),
      ),
    );
  }
}

const _pbKicker = TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, letterSpacing: 1.1, color: AppColors.inkSoft);
const _pbTitle = TextStyle(fontFamily: Fonts.bodyBold, fontSize: 14, color: AppColors.ink);
const _pbSub = TextStyle(fontFamily: Fonts.body, fontSize: 12, color: AppColors.inkSoft);

class ContextRow extends StatelessWidget {
  final IconName icon;
  final String label;
  final String value;
  const ContextRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        IconTile(icon, tone: PillTone.lime, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _pbKicker),
            Padding(padding: const EdgeInsets.only(top: 1), child: Text(value, style: _pbTitle)),
          ]),
        ),
      ]),
    );
  }
}

// ---------- Save error banner ----------

class SaveError {
  final bool offline;
  final VoidCallback retry;
  const SaveError({required this.offline, required this.retry});
}

class SaveErrorBanner extends StatelessWidget {
  final SaveError? error;
  const SaveErrorBanner(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Banner(
        icon: e.offline ? 'wifi-off' : 'refresh-cw',
        tone: PillTone.bad,
        title: e.offline ? tr('You’re offline') : tr('We couldn’t save this change'),
        body: e.offline ? tr('Reconnect to save this change. Nothing was changed.') : tr('Your setting wasn’t changed. Try again.'),
        action: e.offline ? tr('Retry') : tr('Try again'),
        onAction: e.retry,
      ),
    );
  }
}
