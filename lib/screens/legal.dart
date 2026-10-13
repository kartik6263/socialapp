import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../api/client.dart' show appVersionString;
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../util/format.dart';
import '../util/misc.dart';
import '../widgets/parts.dart';
import '../widgets/ui.dart';

const _titles = {
  'privacy': 'Privacy policy',
  'terms': 'Terms of service',
  'refund-policy': 'Refund policy',
  'cookie-policy': 'Cookie & storage policy',
  'faq': 'Help & FAQ',
};

/// A policy page, edited by the team in the Admin Console (Content → Pages & policies).
class LegalPageScreen extends StatefulWidget {
  final String slug;
  const LegalPageScreen({super.key, required this.slug});
  @override
  State<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends State<LegalPageScreen> {
  ContentPage? page;
  ApiError? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => error = null);
    ContentApi.page(widget.slug).then((p) {
      if (mounted) setState(() => page = p);
    }).catchError((e) {
      if (mounted) setState(() => error = e is ApiError ? e : ApiError(0, 'ERROR', tr('Couldn’t load this')));
    });
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final p = page;
    final title = p?.title ?? tr(_titles[widget.slug] ?? 'Policy');
    final draft = p != null && RegExp(r'\[[^\]]+\]').hasMatch(p.body);
    return Screen(children: [
      Header(kicker: tr('LEGAL'), title: title),
      if (error != null)
        (error!.status == 404
            ? ErrorBlock(message: tr('This page isn’t published yet.'), title: tr('Couldn’t load this page'), onRetry: _load)
            : ErrorBlock.of(error!, title: tr('Couldn’t load this page'), onRetry: _load))
      else if (p == null)
        const Skeleton(rows: 5)
      else
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Col(gap: 14, [
            if (draft) Note(tr('Some details on this page (shown in [brackets]) are still being completed.'), icon: 'info'),
            Markdown(p.body),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Txt(tr('Last changed {date}', {'date': enLongDate(p.updatedAt)}), variant: TV.caption),
            ),
          ]),
        ),
    ]);
  }
}

/// Accessibility statement: what we support, and how to tell us when something doesn't work.
class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final user = context.watch<AuthState>().user;
    return Screen(children: [
      Header(kicker: tr('ABOUT'), title: tr('Accessibility')),
      Txt(tr('We aim for WCAG 2.2 level AA. Here’s what Plans supports today.')),
      SectionTitle(tr('Supported')),
      Group([
        ListRow(first: true, icon: 'volume-2', label: tr('Screen readers'), sub: tr('TalkBack and VoiceOver: every button, switch and image has a label; headings are marked.')),
        ListRow(icon: 'type', label: tr('Text size'), sub: tr('Follows your phone’s font size setting.')),
        ListRow(icon: 'pause-circle', label: tr('Reduce motion'), sub: tr('Animations turn off when your phone’s reduce-motion setting is on.')),
        ListRow(icon: 'droplet', label: tr('Colour contrast'), sub: tr('Text meets 4.5:1 contrast, checked against the glass backgrounds. State is never shown by colour alone.')),
        ListRow(icon: 'command', label: tr('Keyboard & switch access'), sub: tr('Use Tab or a switch to move between controls; the focused control shows a blue outline.')),
        ListRow(icon: 'maximize', label: tr('Touch targets'), sub: tr('Buttons are at least 44 points tall.')),
      ]),
      SectionTitle(tr('Known limits')),
      Group([ListRow(first: true, icon: 'globe', label: tr('Translations'), sub: tr('Policy pages are in English only for now.'))]),
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: (user?.onboarded ?? false)
            ? Button(tr('Report an accessibility problem'),
                kind: BK.secondary, icon: 'flag', onPress: () => openReport(ReportParams(targetType: 'PROBLEM', title: tr('Accessibility problem'))))
            : Button(tr('Contact details'), kind: BK.secondary, icon: 'mail', onPress: () => Nav.push('/legal/business')),
      ),
    ]);
  }
}

/// Who runs Plans and how to reach them: required in-app disclosure (IT Rules 2021 grievance officer, app store contact).
class BusinessDetailsScreen extends StatelessWidget {
  const BusinessDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    String show(String v) => isPlaceholder(v) ? tr('To be added') : v;
    VoidCallback? mail(String address, String subject) {
      final to = emailOrNull(address);
      return to != null ? () => launchUrl(mailto(to, subject: subject)) : null;
    }

    return Screen(children: [
      Header(kicker: tr('ABOUT'), title: tr('Business details')),
      Txt(tr('Plans is a product of the company below. Use these details for legal, privacy or grievance matters.')),
      SectionTitle(tr('Company')),
      Group([
        ListRow(first: true, icon: 'briefcase', label: tr('Legal name'), value: show(Business.legalName)),
        ListRow(icon: 'map-pin', label: tr('Registered address'), sub: show(Business.registeredAddress)),
        ListRow(icon: 'hash', label: tr('Company registration (CIN)'), value: show(Business.cin)),
        ListRow(icon: 'file-text', label: tr('GSTIN'), value: show(Business.gstin)),
      ]),
      SectionTitle(tr('Contact')),
      Group([
        ListRow(first: true, icon: 'mail', label: tr('Support'), value: show(Business.supportEmail), onPress: mail(Business.supportEmail, 'Plans support')),
        ListRow(icon: 'lock', label: tr('Privacy & data requests'), value: show(Business.privacyEmail), onPress: mail(Business.privacyEmail, 'Privacy request')),
      ]),
      SectionTitle(tr('Grievance Officer')),
      Group([
        ListRow(first: true, icon: 'user', label: tr('Name'), value: show(Business.grievanceOfficerName)),
        ListRow(icon: 'mail', label: tr('Email'), value: show(Business.grievanceOfficerEmail), onPress: mail(Business.grievanceOfficerEmail, 'Grievance')),
        ListRow(icon: 'clock', label: tr('First response'), value: show(Business.responseTime)),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Txt(tr('If your complaint isn’t resolved, you can escalate it to the Data Protection Board of India.'), variant: TV.small),
      ),
      SectionTitle(tr('Delete your data without the app')),
      Note(
        tr('Signed in? Use Settings → Deactivate or delete. Can’t sign in? Email the privacy address above from the email or phone number on your account, and we’ll verify it’s you and delete your data.'),
        icon: 'trash-2',
      ),
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Txt(tr('Plans version {v}', {'v': appVersionString}), variant: TV.caption, align: TextAlign.center),
      ),
    ]);
  }
}

/// Every policy and legal detail in one place. Works signed out, so people can read it before creating an account.
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final user = context.watch<AuthState>().user;
    final signedIn = user != null && user.onboarded;
    VoidCallback page(String slug) => () => Nav.push('/legal/$slug');

    return Screen(children: [
      Header(kicker: tr('PLANS'), title: tr('Legal & privacy')),
      Txt(tr('Plain-language policies. You can read them any time, signed in or not.')),
      SectionTitle(tr('Policies')),
      Group([
        ListRow(first: true, icon: 'lock', label: tr('Privacy policy'), sub: tr('What we collect, why, and your rights'), onPress: page('privacy')),
        ListRow(icon: 'file-text', label: tr('Terms of service'), sub: tr('The agreement for using Plans'), onPress: page('terms')),
        ListRow(icon: 'rotate-ccw', label: tr('Refund policy'), sub: tr('Paid event tickets and refunds'), onPress: page('refund-policy')),
        ListRow(icon: 'database', label: tr('Cookie & storage policy'), sub: tr('What the app keeps on your phone'), onPress: page('cookie-policy')),
        if (signedIn) ListRow(icon: 'flag', label: tr('Community guidelines'), onPress: () => Nav.push('/safety/guidelines')),
      ]),
      SectionTitle(tr('Your data')),
      Group([
        if (signedIn) ...[
          ListRow(first: true, icon: 'download', label: tr('Download your data'), sub: tr('Get a copy of everything we hold about you'), onPress: () => Nav.push('/settings/data')),
          ListRow(icon: 'sliders', label: tr('Data & consent'), sub: tr('Analytics, offers and emails'), onPress: () => Nav.push('/settings/data')),
          ListRow(icon: 'trash-2', label: tr('Delete your account'), sub: tr('Removes your data after a 30-day grace period'), onPress: () => Nav.push('/settings/lifecycle')),
        ] else
          ListRow(first: true, icon: 'trash-2', label: tr('Delete an account without the app'), sub: tr('How to ask us to delete your data'), onPress: () => Nav.push('/legal/business')),
      ]),
      SectionTitle(tr('About')),
      Group([
        ListRow(first: true, icon: 'briefcase', label: tr('Business details'), sub: tr('Who runs Plans, and the Grievance Officer'), onPress: () => Nav.push('/legal/business')),
        ListRow(icon: 'package', label: tr('Third-party services & licences'), sub: tr('Every SDK in the app, and fonts and images'), onPress: () => Nav.push('/legal/licenses')),
        ListRow(icon: 'eye', label: tr('Accessibility'), sub: tr('How Plans works with assistive technology'), onPress: () => Nav.push('/legal/accessibility')),
      ]),
    ]);
  }
}

/// Third-party SDK audit, shown to users. Keep in step with pubspec.yaml: every SDK that ships in the app is listed
/// with what it does, whether it sends anything off the device, and its licence.
const _sdks = [
  ('Flutter', 'The app framework', 'Nothing sent to Google at runtime', 'BSD-3-Clause', false),
  ('Firebase Messaging', 'Push notifications, only if you turn them on',
      'A device push token, sent to our server and to Google (Firebase) or Apple to deliver notifications', 'Apache-2.0', true),
  ('Flutter Local Notifications', 'Shows push notifications while the app is open', 'Nothing', 'BSD-3-Clause', false),
  ('Flutter Secure Storage', 'Keeps you signed in', 'Sign-in tokens, in your phone’s encrypted Keychain / Keystore', 'BSD-3-Clause', false),
  ('Device Info & Package Info', 'Names your session (e.g. “Pixel 7”)', 'Phone model and app version, sent to our server only', 'BSD-3-Clause', false),
  ('Path Provider & Share Plus', '“Download your data”', 'Writes the export to your phone, then opens the share sheet', 'BSD-3-Clause', false),
  ('URL Launcher & Web Auth', 'Opens links you tap', 'Nothing, until you open a link', 'BSD-3-Clause', false),
  ('Permission Handler', 'Asks for notification permission', 'Nothing', 'MIT', false),
  ('go_router & Provider', 'Navigation and app state', 'Nothing', 'BSD-3-Clause / MIT', false),
  ('STOMP Dart Client', 'Real-time chat', 'Your messages, to our server only', 'BSD-3-Clause', true),
];

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Screen(children: [
      Header(kicker: tr('ABOUT'), title: tr('Third-party services')),
      Txt(tr('Every SDK inside the app, what it’s for, and what (if anything) leaves your phone.')),
      Note(
        tr('No advertising, tracking or third-party analytics SDKs are included. Product analytics go only to our own server, and only if you agree.'),
        icon: 'shield',
      ),
      SectionTitle(tr('SDKs in the app')),
      Group([
        for (final (i, s) in _sdks.indexed)
          ListRow(
            first: i == 0,
            icon: s.$5 ? 'wifi' : 'smartphone',
            label: s.$1,
            sub: '${tr(s.$2)} · ${tr(s.$3)}',
            right: Pill(s.$4, tone: PillTone.neutral),
          ),
      ]),
      SectionTitle(tr('Fonts')),
      Group([
        ListRow(first: true, icon: 'type', label: 'Manrope', sub: tr('By Mikhail Sharanda. Bundled in the app.'), right: const Pill('OFL 1.1', tone: PillTone.neutral)),
        ListRow(icon: 'type', label: 'DM Sans', sub: tr('By Colophon Foundry for Google Fonts. Bundled in the app.'), right: const Pill('OFL 1.1', tone: PillTone.neutral)),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Txt(tr('SIL Open Font License 1.1 allows embedding in apps. Fonts load from the app itself, never from Google’s servers.'), variant: TV.small),
      ),
      SectionTitle(tr('Icons & images')),
      Group([
        ListRow(first: true, icon: 'feather', label: 'Feather icons', sub: tr('By Cole Bemis. Bundled in the app.'), right: const Pill('MIT', tone: PillTone.neutral)),
        ListRow(icon: 'image', label: tr('Plan cover art'), sub: tr('Drawn by the app from shapes and colours. No stock photos are used.'), right: Pill(tr('Original'), tone: PillTone.ok)),
        ListRow(icon: 'user', label: tr('Profile pictures'), sub: tr('Shown as initials. Photo upload isn’t available yet.')),
      ]),
    ]);
  }
}
