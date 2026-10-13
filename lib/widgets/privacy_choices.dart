import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:flutter/gestures.dart';

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import 'parts.dart';
import 'ui.dart';

bool _checked = false;

/// The app's consent prompt (it has no cookies; this covers the optional data uses instead). Shown once, after sign-in,
/// until the person answers. Rules it follows on purpose:
/// - optional uses start OFF; "Reject all" and "Accept all" look identical, so neither is nudged;
/// - essential uses are explained but not toggleable;
/// - the choice can be changed any time in Settings → Your data.
Future<void> checkPrivacyChoices() async {
  if (_checked) return;
  _checked = true;
  try {
    final c = await PrivacyApi.consents();
    setAnalyticsAllowed(c.analytics);
    if (c.decided) return;
  } catch (_) {
    // offline: ask next launch; nothing optional runs meanwhile
    _checked = false;
    return;
  }
  final ctx = Nav.rootKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  await showGeneralDialog<void>(
    context: ctx,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: const Color.fromRGBO(15, 25, 23, 0.4),
    transitionDuration: Motion.slow,
    transitionBuilder: (context, a, _, child) {
      if (reducedMotion(context)) return child;
      final t = CurvedAnimation(parent: a, curve: Curves.easeOut);
      return FadeTransition(
        opacity: t,
        child: AnimatedBuilder(animation: t, builder: (_, c) => Transform.translate(offset: Offset(0, 40 * (1 - t.value)), child: c), child: child),
      );
    },
    pageBuilder: (_, _, _) => const PopScope(canPop: false, child: _PrivacyChoices()),
  );
}

/// Lets a new session ask again (after sign-out / sign-in).
void resetPrivacyChoices() => _checked = false;

class _PrivacyChoices extends StatefulWidget {
  const _PrivacyChoices();
  @override
  State<_PrivacyChoices> createState() => _PrivacyChoicesState();
}

class _PrivacyChoicesState extends State<_PrivacyChoices> {
  bool custom = false;
  bool analytics = false;
  bool offers = false;
  bool emails = false;
  String? busy;
  String? error;

  // Policies open inside the prompt (a separate screen would sit underneath it).
  Object? reading; // ContentPage | 'loading' | 'error' | null

  Future<void> _save(String which, {required bool analytics, required bool offers, required bool marketingEmails}) async {
    setState(() {
      busy = which;
      error = null;
    });
    try {
      final saved = await PrivacyApi.saveConsents(analytics: analytics, offers: offers, marketingEmails: marketingEmails, source: 'PROMPT');
      setAnalyticsAllowed(saved.analytics);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  void _policy(String slug) {
    setState(() => reading = 'loading');
    ContentApi.page(slug).then((p) {
      if (mounted) setState(() => reading = p);
    }).catchError((_) {
      if (mounted) setState(() => reading = 'error');
    });
  }

  Widget _line(bool on, String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: Text(on ? '●' : '○', style: TextStyle(fontSize: 12, height: 19 / 12, color: on ? AppColors.brand : AppColors.inkSoft))),
        const SizedBox(width: 8),
        Expanded(child: Txt(text, variant: TV.small, style: const TextStyle(fontSize: 13))),
      ]);

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final mq = MediaQuery.of(context);
    final r = reading;
    const link = TextStyle(fontFamily: Fonts.bodyBold, color: AppColors.brand, decoration: TextDecoration.underline);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: tr('Your privacy choices'),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
            padding: EdgeInsets.fromLTRB(20, 20, 20, mq.padding.bottom + 18),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(247, 250, 247, 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: GlassTokens.border),
            ),
            child: SingleChildScrollView(
              child: r != null
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 520),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                        Start(Button(tr('Back to choices'), kind: BK.text, icon: 'chevron-left', onPress: () => setState(() => reading = null))),
                        if (r == 'loading')
                          Txt(tr('Loading…'), variant: TV.small)
                        else if (r == 'error')
                          Txt(tr('Couldn’t load this page. You can read it later in Settings → Legal & privacy.'), variant: TV.small)
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(top: 6),
                              child: Markdown((r as ContentPage).body),
                            ),
                          ),
                      ]),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        const IconTile('sliders', size: 44),
                        const SizedBox(width: 12),
                        Expanded(child: Txt(tr('Your privacy choices'), variant: TV.heading, header: true, style: const TextStyle(fontSize: 19))),
                      ]),
                      const SizedBox(height: 10),
                      Txt(tr('Plans works fully without these. They’re off unless you turn them on, and you can change them any time in Settings → Your data.')),
                      if (custom)
                        Group(margin: const EdgeInsets.only(top: 14), [
                          ToggleRow(first: true, label: tr('Product analytics'), sub: tr('Counts of actions like “Plan joined”. No messages, no location, no ads.'),
                              value: analytics, onChange: (v) => setState(() => analytics = v)),
                          ToggleRow(label: tr('Offers & promotions'), sub: tr('Occasional notifications about event deals.'),
                              value: offers, onChange: (v) => setState(() => offers = v)),
                          ToggleRow(label: tr('Update emails'), sub: tr('News by email, with an unsubscribe link in every one.'),
                              value: emails, onChange: (v) => setState(() => emails = v)),
                        ])
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Col(gap: 8, [
                            _line(false, tr('Product analytics — off until you choose')),
                            _line(false, tr('Offers & promotions — off until you choose')),
                            _line(true, tr('Essential: sign-in, your profile, Plans, chat and safety — always on')),
                          ]),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: tr('Privacy policy'), style: link, recognizer: TapGestureRecognizer()..onTap = () => _policy('privacy')),
                            const TextSpan(text: '   ·   '),
                            TextSpan(text: tr('Cookie & storage policy'), style: link, recognizer: TapGestureRecognizer()..onTap = () => _policy('cookie-policy')),
                          ]),
                          style: const TextStyle(fontFamily: Fonts.body, fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Semantics(liveRegion: true, child: Txt(error, variant: TV.small, style: const TextStyle(color: AppColors.dangerText))),
                        ),
                      if (custom)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Button(tr('Save my choices'), loading: busy == 'custom', disabled: busy != null,
                              onPress: () => _save('custom', analytics: analytics, offers: offers, marketingEmails: emails)),
                        )
                      else ...[
                        // Same style, same size, side by side: no nudging towards "accept".
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(children: [
                            Expanded(
                              child: Button(tr('Reject all'), kind: BK.secondary, loading: busy == 'reject', disabled: busy != null,
                                  onPress: () => _save('reject', analytics: false, offers: false, marketingEmails: false)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Button(tr('Accept all'), kind: BK.secondary, loading: busy == 'accept', disabled: busy != null,
                                  onPress: () => _save('accept', analytics: true, offers: true, marketingEmails: true)),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Button(tr('Choose for myself'), kind: BK.text, disabled: busy != null, onPress: () => setState(() => custom = true)),
                        ),
                      ],
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}
