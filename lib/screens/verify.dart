import 'dart:async';

import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/focus_data.dart';
import '../util/format.dart';
import '../widgets/trust_signals.dart';
import '../widgets/ui.dart';

const _v = <String, (String, PillTone)>{
  'NOT_STARTED': ('Not verified', PillTone.neutral),
  'PENDING': ('Verification pending', PillTone.blue),
  'IN_PROGRESS': ('In progress', PillTone.blue),
  'VERIFIED': ('Verified', PillTone.ok),
  'NEEDS_ATTENTION': ('Needs attention', PillTone.warn),
  'EXPIRED': ('Expired', PillTone.neutral),
  'FAILED': ('Couldn’t be completed', PillTone.bad),
  'UNAVAILABLE': ('Unavailable', PillTone.neutral),
};

const _o = <String, (String, PillTone, String, String?)>{
  'NONE': ('Not started', PillTone.neutral, 'Only for people who host community or official events.', 'Learn more'),
  'INCOMPLETE': ('Setup incomplete', PillTone.neutral, 'Continue where you left off.', 'Continue'),
  'SUBMITTED': ('Submitted', PillTone.blue, 'We’ve received your details.', 'View'),
  'IN_REVIEW': ('In review', PillTone.blue, 'We’re checking the organisation’s details.', 'View'),
  'MORE_INFO': ('More information needed', PillTone.warn, 'Add the missing detail to continue.', 'View'),
  'VERIFIED': ('Verified', PillTone.ok, 'Your organizer profile shows Organizer verified.', 'View'),
  'FAILED': ('Couldn’t be completed', PillTone.bad, 'We couldn’t confirm the organisation’s details.', 'Try again'),
  'EXPIRED': ('Expired', PillTone.neutral, 'Official status is paused until you verify again.', 'Verify again'),
  'UNAVAILABLE': ('Unavailable', PillTone.neutral, 'Organizer verification isn’t currently available.', null),
};

const _idSub = <String, (String, String?)>{
  'NOT_STARTED': ('Adds Identity verified to your profile. Takes about 3 minutes.', 'Verify'),
  'PENDING': ('We’re processing your verification. We’ll notify you when it’s done.', 'View'),
  'IN_PROGRESS': ('We’re processing your verification. We’ll notify you when it’s done.', 'View'),
  'VERIFIED': ('Shown on your profile as Identity verified.', null),
  'NEEDS_ATTENTION': ('Your ID expires soon. Verify again to keep the signal after that.', 'Verify again'),
  'EXPIRED': ('The signal is no longer shown on your profile. Verify again to add it back.', 'Verify again'),
  'FAILED': ('Your last attempt couldn’t be matched. Nothing was added to your profile.', 'Try again'),
  'UNAVAILABLE': ('Identity verification isn’t currently available. Your profile works normally without it.', null),
};

// ---------- Verification center ----------

class VerificationCenterScreen extends StatefulWidget {
  const VerificationCenterScreen({super.key});
  @override
  State<VerificationCenterScreen> createState() => _VerificationCenterScreenState();
}

class _VerificationCenterScreenState extends State<VerificationCenterScreen> with FocusData<VerificationCenterScreen, VerificationState> {
  @override
  Future<VerificationState> load() => VerificationApi.state();

  Widget _row(IconName icon, String label, (String, PillTone) status, String sub, String? cta, VoidCallback run) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon, tone: status.$2 == PillTone.ok ? PillTone.ok : PillTone.neutral),
          const SizedBox(width: 12),
          Expanded(
            child: Col(gap: 4, [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                Txt(label, variant: TV.bodyStrong),
                Pill(tr(status.$1), tone: status.$2),
              ]),
              Txt(tr(sub), variant: TV.small),
              if (cta != null) Padding(padding: const EdgeInsets.only(top: 4), child: Start(Button(tr(cta), compact: true, kind: BK.secondary, onPress: run))),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final v = data;
    Widget explainRow(String label, String sub, VoidCallback onTap, bool first) => Pressable(
          onPress: onTap,
          label: '$label, $sub',
          focusRadius: BorderRadius.zero,
          builder: (_, _, _) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Txt(label, variant: TV.bodyStrong), Txt(sub, variant: TV.small)])),
              const SizedBox(width: 12),
              const FIcon('arrow-right', size: 14, color: AppColors.brand),
            ]),
          ),
        );

    return Screen(children: [
      Header(kicker: tr('PROFILE'), title: tr('Verification')),
      Txt(tr('Complete verification to add useful trust signals to your profile.')),
      if (loading)
        const Skeleton(rows: 4)
      else if (error != null && v == null)
        (error!.isNetwork
            ? StateBlock(
                icon: 'wifi-off',
                tone: PillTone.neutral,
                title: tr('Verification status unavailable while offline'),
                body: tr('We don’t show saved verification status offline, so nothing here can be out of date.'),
                actions: [StateAction(tr('Retry'), refresh)],
              )
            : ErrorBlock.of(error!, onRetry: refresh, title: tr('We couldn’t load verification status')))
      else if (v != null) ...[
        if (me.signals.isNotEmpty)
          Group(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(top: 14), [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Txt(tr('SHOWN ON YOUR PROFILE'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft))),
            TrustSignals(signals: me.signals, name: 'You'),
          ])
        else
          Group(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(top: 14), [
            Txt(tr('No verification completed yet'), variant: TV.bodyStrong),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Txt(tr('Complete available verification steps to add trust signals to your profile. Your profile works normally either way.'), variant: TV.small),
            ),
          ]),
        SectionTitle(tr('Identity')),
        Group([
          _row('user', tr('Identity verification'), _v[v.identity.status] ?? _v['NOT_STARTED']!, (_idSub[v.identity.status] ?? _idSub['NOT_STARTED']!).$1,
              (_idSub[v.identity.status] ?? _idSub['NOT_STARTED']!).$2, () => Nav.push('/verify/identity')),
        ]),
        SectionTitle(tr('Contact')),
        Group([
          _row(
            'lock',
            tr('Phone verification'),
            _v[v.phone.status] ?? _v['NOT_STARTED']!,
            v.phone.status == 'VERIFIED' ? tr('{v} · Shown as Phone verified', {'v': v.phone.masked ?? ''}) : tr('Confirm your number with a one-time code.'),
            v.phone.status == 'VERIFIED' ? null : tr('Verify'),
            () => Nav.push('/verify/phone'),
          ),
          Container(height: 1, color: AppColors.divider),
          _row(
            'message-circle',
            tr('Email verification'),
            _v[v.email.status] ?? _v['NOT_STARTED']!,
            v.email.status == 'VERIFIED'
                ? tr('{v} · Shown as Email verified', {'v': v.email.masked ?? ''})
                : v.email.status == 'PENDING'
                    ? tr('Link sent to {masked}', {'masked': v.email.masked})
                    : tr('Confirm your email with a link.'),
            v.email.status == 'VERIFIED' ? null : (v.email.status == 'PENDING' ? tr('View') : tr('Verify')),
            () => Nav.push('/verify/email'),
          ),
        ]),
        SectionTitle(tr('Organizer')),
        Group([
          Builder(builder: (context) {
            final o = _o[v.organizer.status] ?? _o['NONE']!;
            final s = v.organizer.status;
            return _row('users', tr('Organizer verification'), (o.$1, o.$2), o.$3, o.$4,
                () => Nav.push(s == 'NONE' || s == 'INCOMPLETE' || s == 'FAILED' ? '/organizer/setup' : '/verify/organizer'));
          }),
        ]),
        SectionTitle(tr('What these mean')),
        Group([
          for (final (i, s) in const ['IDENTITY', 'PHONE', 'EMAIL', 'ORGANIZER', 'OFFICIAL'].indexed)
            explainRow(signalLabel(s), signalMeaning(s), () => showSignalExplainer(context, ExplainSignal(s)), i == 0),
          explainRow(tr('About trust signals'), tr('Why you see them, and what they never mean'), () => showSignalExplainer(context, const ExplainAbout()), false),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Note(tr('Your privacy matters. People see the result — like Identity verified — never your documents, ID number, phone number or email address.')),
        ),
      ],
    ]);
  }
}

// ---------- Email ----------

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> with FocusData<EmailVerificationScreen, VerificationState> {
  bool changing = false;
  String draft = '';
  bool sent = false;
  String? err;
  bool busy = false;

  @override
  Future<VerificationState> load() async {
    final s = await VerificationApi.state();
    if (s.email.status == 'VERIFIED' && mounted) authOf(context).refreshUser().catchError((_) {});
    return s;
  }

  Future<void> _sendLink([String? email]) async {
    if (email != null && !_emailRe.hasMatch(email.trim())) return setState(() => err = tr('Enter a valid email address.'));
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final s = await VerificationApi.sendEmailLink(email?.trim());
      if (!mounted) return;
      setState(() {
        data = s;
        sent = true;
        changing = false;
      });
    } catch (e) {
      if (mounted) setState(() => err = e is ApiError ? e.message : tr('Couldn’t send the link.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final header = Header(kicker: tr('VERIFICATION'), title: tr('Email'));
    if (loading) return Screen(children: [header, const Loading()]);
    final v = data;
    if (v == null) return Screen(children: [header, if (error != null) ErrorBlock.of(error!, onRetry: refresh)]);
    if (v.email.status == 'VERIFIED') {
      return Screen(children: [
        header,
        StateBlock(
          icon: 'check',
          title: tr('Email verified'),
          body: tr('Your address stays private. Other people only see Email verified on your profile.'),
          actions: [StateAction(tr('Done'), Nav.back)],
        ),
      ]);
    }
    return Screen(bottom: true, children: [
      header,
      if (changing || v.email.masked == null) ...[
        Txt(v.email.masked != null ? tr('Change email') : tr('Add your email'), variant: TV.title),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Txt(tr('We’ll send a verification link. Your address is never shown to other people.'))),
        Field(
          label: tr('Email address'),
          value: draft,
          onChanged: (t) => setState(() => draft = t),
          keyboardType: TextInputType.emailAddress,
          capitalization: TextCapitalization.none,
          autofill: const [AutofillHints.email],
          placeholder: tr('name@example.com'),
          error: err,
        ),
        Button(tr('Send verification link'), loading: busy, onPress: () => _sendLink(draft)),
        if (v.email.masked != null) Button(tr('Cancel'), kind: BK.text, onPress: () => setState(() => changing = false)),
      ] else ...[
        const Start(IconTile('message-circle', size: 52)),
        Padding(padding: const EdgeInsets.only(top: 14), child: Txt(tr('Verify your email'), variant: TV.title)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Txt.rich(trRich('We sent a verification link to {email}. Open it on any device to finish.', {'email': bold(v.email.masked!)})),
        ),
        Pill(tr('Verification pending'), tone: PillTone.blue, icon: 'clock'),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Txt(err, variant: TV.small, style: const TextStyle(color: AppColors.danger))),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Col(gap: 8, [
            Button(sent ? tr('Sent again — check your inbox') : tr('Resend verification email'), kind: BK.secondary, disabled: sent, loading: busy, onPress: () => _sendLink()),
            Button(tr('Change email'), kind: BK.text, onPress: () => setState(() => changing = true)),
            Button(tr('I’ve opened the link'), onPress: refresh),
          ]),
        ),
      ],
    ]);
  }
}

// ---------- Identity ----------

const _checks = [
  'A photo of a government ID (Aadhaar, PAN, passport or driving licence)',
  'A short selfie video to match your face to the ID',
  'That the name and age range match your profile',
];

/// Identity verification is run by a licensed IDV provider in a hosted flow; we only ever receive the result.
/// The app opens the provider session, then polls our backend until the provider's webhook lands.
class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});
  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  String step = 'intro'; // intro | processing | success | failed | unavailable
  bool busy = false;
  String? error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    VerificationApi.state().then((s) {
      if (!mounted) return;
      final st = s.identity.status;
      if (st == 'UNAVAILABLE') {
        setState(() => step = 'unavailable');
      } else if (st == 'IN_PROGRESS' || st == 'PENDING') {
        _startPolling();
      } else if (st == 'VERIFIED') {
        setState(() => step = 'success');
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    final auth = authOf(context);
    setState(() => step = 'processing');
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final s = await VerificationApi.state();
        final st = s.identity.status;
        if (st == 'VERIFIED') {
          _poll?.cancel();
          await auth.refreshUser();
          if (mounted) setState(() => step = 'success');
        } else if (st == 'FAILED') {
          _poll?.cancel();
          if (mounted) setState(() => step = 'failed');
        } else if (st == 'UNAVAILABLE') {
          _poll?.cancel();
          if (mounted) setState(() => step = 'unavailable');
        }
      } catch (_) {
        // keep polling; the user can leave and will get a notification
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await VerificationApi.startIdentity();
      if (session.providerUrl != null) {
        try {
          await FlutterWebAuth2.authenticate(url: session.providerUrl!, callbackUrlScheme: 'plans');
        } catch (_) {
          // Closing the provider page is fine: the result arrives by webhook either way.
        }
      }
      await VerificationApi.submitIdentity(session.sessionId);
      if (mounted) _startPolling();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'IDV_UNAVAILABLE') {
        setState(() => step = 'unavailable');
      } else {
        setState(() => error = e is ApiError ? e.message : tr('Couldn’t start verification. Try again.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _exit() => Nav.back();

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Screen(bottom: true, children: [
      Header(title: tr('Identity verification'), center: true, right: IconBtn('x', label: tr('Exit verification'), onPress: _exit)),
      if (step == 'intro') ...[
        const Start(IconTile('shield', size: 56)),
        Padding(padding: const EdgeInsets.only(top: 14), child: Txt(tr('Verify your identity'), variant: TV.display, style: const TextStyle(fontSize: 28))),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Txt(tr('Verification helps other people understand that your profile represents a real, verified identity.')),
        ),
        SectionTitle(tr('What we’ll check')),
        for (final (i, c) in _checks.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.brandPale, shape: BoxShape.circle),
                child: Text('${i + 1}', style: const TextStyle(color: AppColors.brand, fontFamily: Fonts.bodyBold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Txt(tr(c), variant: TV.small, style: const TextStyle(color: AppColors.ink))),
            ]),
          ),
        SectionTitle(tr('Why it exists')),
        Txt.rich(trRich('It adds {signal} to your profile. It doesn’t rank you, and it doesn’t change who can see your Plans.', {'signal': bold(tr('Identity verified'))})),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Note(tr('Your ID is checked by our verification partner and used only for this check. People see the result — never your document, ID number or date of birth.')),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Txt(error, variant: TV.small, style: const TextStyle(color: AppColors.danger))),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Col(gap: 8, [
            Button(tr('Start verification'), loading: busy, onPress: _start),
            Button(tr('Not now'), kind: BK.secondary, onPress: _exit),
          ]),
        ),
      ],
      if (step == 'processing')
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: AppColors.brand))),
              Padding(padding: const EdgeInsets.only(top: 18), child: Txt(tr('Verification in progress'), variant: TV.title, align: TextAlign.center)),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Txt(tr('This usually takes a few minutes — you can leave this screen and we’ll notify you.'), align: TextAlign.center),
              ),
              Padding(padding: const EdgeInsets.only(top: 20), child: Button(tr('Back to Verification'), kind: BK.secondary, onPress: _exit)),
            ]),
          ),
        ),
      if (step == 'success')
        StateBlock(
          icon: 'check',
          title: tr('Identity verified'),
          body: tr('Verification completed. Your profile now shows Identity verified. It doesn’t rank you or change who sees your Plans.'),
          actions: [StateAction(tr('View my profile'), () => Nav.navigate('/me')), StateAction(tr('Done'), _exit, BK.secondary)],
        ),
      if (step == 'failed')
        StateBlock(
          icon: 'refresh-cw',
          tone: PillTone.bad,
          title: tr('Verification couldn’t be completed'),
          body: tr('The photos couldn’t be matched — glare or blur is the usual cause. Nothing from this attempt appears on your profile.'),
          actions: [StateAction(tr('Try again'), () => setState(() => step = 'intro')), StateAction(tr('Exit'), _exit, BK.secondary)],
        ),
      if (step == 'unavailable')
        StateBlock(
          icon: 'clock',
          tone: PillTone.neutral,
          title: tr('Verification isn’t currently available'),
          body: tr('Identity verification is temporarily unavailable. Your profile works normally without it — you can try again later.'),
          actions: [StateAction(tr('Back to Verification'), _exit)],
        ),
    ]);
  }
}

// ---------- Organizer verification ----------

class OrganizerVerificationScreen extends StatefulWidget {
  const OrganizerVerificationScreen({super.key});
  @override
  State<OrganizerVerificationScreen> createState() => _OrganizerVerificationScreenState();
}

class _OrganizerVerificationScreenState extends State<OrganizerVerificationScreen> with FocusData<OrganizerVerificationScreen, VerificationState> {
  @override
  Future<VerificationState> load() => VerificationApi.state();

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final header = Header(kicker: tr('VERIFICATION'), title: tr('Organizer verification'));
    if (loading) return Screen(children: [header, const Loading()]);
    final v = data;
    if (v == null) return Screen(children: [header, if (error != null) ErrorBlock.of(error!, onRetry: refresh)]);

    final o = v.organizer;
    final name = o.name ?? tr('Your organizer profile');
    final pillLabel = switch (o.status) {
      'SUBMITTED' => tr('Submitted'),
      'IN_REVIEW' => tr('In review'),
      'VERIFIED' => tr('Organizer verified'),
      'FAILED' => tr('Couldn’t be completed'),
      'MORE_INFO' => tr('More information needed'),
      'INCOMPLETE' => tr('Setup incomplete'),
      'EXPIRED' => tr('Expired'),
      'UNAVAILABLE' => tr('Unavailable'),
      _ => '',
    };
    final pillTone = switch (o.status) {
      'VERIFIED' => PillTone.ok,
      'FAILED' => PillTone.bad,
      'MORE_INFO' => PillTone.warn,
      _ => PillTone.blue,
    };

    final Widget body = switch (o.status) {
      'NONE' || 'INCOMPLETE' => StateBlock(
          icon: 'users',
          title: tr('Become an organizer'),
          body: tr('For people who host community or official events. It confirms the organisation you host for — it’s separate from your personal Identity verified signal.'),
          actions: [StateAction(o.status == 'NONE' ? tr('Start organizer verification') : tr('Continue setup'), () => Nav.replace('/organizer/setup'))],
        ),
      'SUBMITTED' || 'IN_REVIEW' => Banner(
          icon: 'clock',
          tone: PillTone.blue,
          title: tr('In review'),
          body: tr('We’re checking the organisation’s details. This usually takes 1–2 working days. We’ll notify you.'),
        ),
      'MORE_INFO' => StateBlock(
          icon: 'info',
          tone: PillTone.warn,
          title: tr('More information needed'),
          body: tr('Check your email from Plans for what’s missing, then update your details.'),
          actions: [StateAction(tr('Update details'), () => Nav.replace('/organizer/setup'))],
        ),
      'VERIFIED' => StateBlock(
          icon: 'check',
          title: tr('Organizer verified'),
          body: tr('{name} shows Organizer verified. Your personal profile signals haven’t changed.', {'name': name}),
          actions: [StateAction(tr('View organizer profile'), () => Nav.replace('/organizer/${o.organizerId}'))],
        ),
      'FAILED' => StateBlock(
          icon: 'refresh-cw',
          tone: PillTone.bad,
          title: tr('Organizer verification couldn’t be completed'),
          body: tr('We couldn’t confirm the organisation’s details. Check the website and contact email, then try again.'),
          actions: [StateAction(tr('Try again'), () => Nav.replace('/organizer/setup')), StateAction(tr('Exit'), Nav.back, BK.secondary)],
        ),
      _ => StateBlock(
          icon: 'clock',
          tone: PillTone.neutral,
          title: tr('Organizer verification isn’t currently available'),
          body: tr('It’s temporarily unavailable. You can still create Plans as usual.'),
          actions: [StateAction(tr('Back to Verification'), Nav.back)],
        ),
    };

    return Screen(children: [
      header,
      if (o.status != 'NONE')
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Avatar(name: name, id: o.organizerId ?? 0, size: 44, tone: AvatarTone.mint),
            const SizedBox(width: 12),
            Expanded(
              child: Col(gap: 4, [
                Txt(tr('YOUR ORGANIZER PROFILE'), variant: TV.kicker, style: const TextStyle(color: AppColors.inkSoft)),
                Txt(name, variant: TV.bodyStrong),
                Pill(pillLabel, tone: pillTone),
              ]),
            ),
          ]),
        ),
      body,
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Txt(tr('We don’t share internal review notes. Organizer verification doesn’t change your personal trust signals.'), variant: TV.small),
      ),
    ]);
  }
}

// ---------- Phone ----------

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});
  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  String step = 'enter'; // enter | locked | verified
  String code = '';
  String? error;
  int resendIn = 0;
  bool busy = false;
  String? devCode;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    setState(() => resendIn = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => resendIn = resendIn > 0 ? resendIn - 1 : 0);
      if (resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() => error = null);
    try {
      final r = await VerificationApi.sendPhoneCode();
      if (!mounted) return;
      devCode = r.devCode;
      _countdown(r.resendInSeconds);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') {
        setState(() => step = 'locked');
      } else {
        setState(() => error = e is ApiError ? e.message : tr('Couldn’t send a code.'));
      }
    }
  }

  Future<void> _verify() async {
    final auth = authOf(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await VerificationApi.verifyPhone(code);
      await auth.refreshUser();
      if (mounted) setState(() => step = 'verified');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') {
          step = 'locked';
        } else {
          error = e is ApiError ? e.message : tr('We couldn’t check your code. Nothing has changed — try again.');
        }
        code = '';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    return Screen(bottom: true, children: [
      Header(kicker: tr('VERIFICATION'), title: tr('Phone')),
      if (step == 'enter') ...[
        const Start(IconTile('lock', size: 52)),
        Padding(padding: const EdgeInsets.only(top: 14), child: Txt(tr('Verify your phone'), variant: TV.title)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Txt.rich(trRich('Enter the 6-digit code we sent to {phone}.', {'phone': bold(me.maskedPhone ?? tr('your phone'))})),
        ),
        Field(
          label: tr('6-digit verification code'),
          value: code,
          onChanged: (t) => setState(() => code = t),
          formatters: [digitsOnly],
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofill: const [AutofillHints.oneTimeCode],
          placeholder: '••••••',
          error: error,
        ),
        Button(tr('Verify'), loading: busy, disabled: code.length < 6, onPress: _verify),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            child: resendIn > 0
                ? Txt('${tr('Resend code in 0:')}${resendIn.toString().padLeft(2, '0')}', variant: TV.small)
                : Button(tr('Resend code'), kind: BK.text, onPress: _send),
          ),
        ),
        if (devCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Txt(tr('Development build · code: {code}', {'code': devCode}), variant: TV.caption, align: TextAlign.center),
          ),
      ],
      if (step == 'locked')
        StateBlock(
          icon: 'lock',
          tone: PillTone.neutral,
          title: tr('Too many attempts'),
          body: tr('For your security, wait 10 minutes before requesting a new code.'),
          actions: [StateAction(tr('Back to Verification'), Nav.back)],
        ),
      if (step == 'verified')
        StateBlock(
          icon: 'check',
          title: tr('Phone verified'),
          body: tr('Your number stays private. Other people only see Phone verified on your profile.'),
          actions: [StateAction(tr('Done'), Nav.back)],
        ),
    ]);
  }
}
