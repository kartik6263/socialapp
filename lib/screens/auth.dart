import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/toast.dart';
import '../util/misc.dart';
import '../widgets/glass.dart';
import '../widgets/parts.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.paper,
        body: Stack(children: [Backdrop(), Center(child: Logo(size: 24))]),
      );
}

// ---------- Welcome ----------

/// People drifting gently around a Plan: the whole idea of the app in one picture. Still when reduce-motion is on.
class _Orbit extends StatefulWidget {
  const _Orbit();
  @override
  State<_Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<_Orbit> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _t.stop();
      _t.value = 0;
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  double _bob(int phase, double dist) {
    // 0 → ±dist → 0 over one loop, eased like Easing.inOut(Easing.sin).
    final eased = -(math.cos(math.pi * _t.value) - 1) / 2;
    final tri = eased < 0.5 ? eased * 2 : (1 - eased) * 2;
    return (phase.isOdd ? 1 : -1) * dist * tri;
  }

  Widget _avatar(String name, AvatarTone tone) => Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.95), width: 3)),
        child: Avatar(name: name, size: 48, tone: tone),
      );

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: GlassTokens.fillStrong, border: Border.all(color: GlassTokens.border), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: AppColors.ink)),
      );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 236,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return AnimatedBuilder(
            animation: _t,
            builder: (context, _) => Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Container(width: 236, height: 236, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color.fromRGBO(18, 107, 85, 0.10)))),
              const SizedBox(width: 190, height: 190, child: CustomPaint(painter: _DashedRing())),
              Positioned(top: 0 + _bob(0, 6), left: w * 0.42, child: _avatar('Riya K', AvatarTone.mint)),
              Positioned(bottom: 10 - _bob(1, 8), left: w * 0.16, child: _avatar('Vikram S', AvatarTone.violet)),
              Positioned(bottom: 36 - _bob(2, 5), right: w * 0.14, child: _avatar('Nisha M', AvatarTone.coral)),
              Transform.rotate(
                angle: -7 * math.pi / 180,
                child: Glass(
                  radius: 24,
                  width: 72,
                  height: 72,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(18)),
                    child: const FIcon('calendar', size: 28, color: AppColors.brandDark),
                  ),
                ),
              ),
              Positioned(top: 46, left: 6, child: _tag(tr('Sunrise trek'))),
              Positioned(top: 70, right: 4, child: _tag(tr('Live music'))),
            ]),
          );
        }),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  const _DashedRing();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(18, 107, 85, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = size.width / 2;
    const dashes = 48;
    for (var i = 0; i < dashes; i++) {
      final a0 = 2 * math.pi * i / dashes;
      canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r), a0, math.pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget _promise(IconName icon, String text) => Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(9)),
          child: FIcon(icon, size: 14, color: AppColors.brandDark),
        ),
        const SizedBox(width: 10),
        Expanded(child: Txt(text, variant: TV.small, style: const TextStyle(color: AppColors.ink))),
      ]);

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final sessionExpired = context.watch<AuthState>().sessionExpired;
    return Screen(bottom: true, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Logo(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: GlassTokens.fillStrong, border: Border.all(color: GlassTokens.border), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const FIcon('shield', size: 12, color: AppColors.brandDark),
              const SizedBox(width: 5),
              Text(tr('Safety by design'), style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: AppColors.brandDark)),
            ]),
          ),
        ]),
      ),
      const LanguagePicker(),
      const _Orbit(),
      if (sessionExpired)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Banner(icon: 'clock', tone: PillTone.warn, title: tr('Your session expired'), body: tr('Sign in again and we’ll take you back to your Plans.')),
        ),
      Appear(
        delay: const Duration(milliseconds: 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Txt(tr('PEOPLE AROUND YOUR PLANS'), variant: TV.kicker),
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 12), child: Headline(text: tr('Tell us what\nyou’re '), accent: tr('doing.'))),
          Txt(tr('We’ll help you discover people doing the same thing—not keep you scrolling endlessly.'), style: const TextStyle(fontSize: 15, height: 22 / 15)),
        ]),
      ),
      Appear(
        delay: const Duration(milliseconds: 160),
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Glass(
            padding: const EdgeInsets.all(14),
            child: Col(gap: 10, [
              _promise('calendar', tr('Real Plans, not an endless feed')),
              _promise('map-pin', tr('Approximate areas only — never your address')),
              _promise('lock', tr('Your phone and email stay private')),
            ]),
          ),
        ),
      ),
      Appear(
        delay: const Duration(milliseconds: 240),
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Col(gap: 10, [
            Button(tr('Get started'), iconRight: 'arrow-right', onPress: () => Nav.push('/sign-in', {'mode': 'signup'})),
            Button(tr('Sign in'), kind: BK.secondary, onPress: () => Nav.push('/sign-in', {'mode': 'login'})),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Txt(tr('Free to use · 18+ only'), variant: TV.caption),
          const SizedBox(width: 6),
          Button(tr('Legal & privacy'), kind: BK.text, compact: true, onPress: () => Nav.push('/legal')),
        ]),
      ),
    ]);
  }
}

// ---------- Sign in ----------

const _codeLength = 6;
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class SignInScreen extends StatefulWidget {
  final String? mode;
  const SignInScreen({super.key, this.mode});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late bool signup = widget.mode != 'login';
  String stage = 'credential';
  String channel = 'PHONE';
  String value = '';
  ConsentState consent = const ConsentState();
  bool consentError = false;
  bool busy = false;
  String? error;
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  int resendIn = 0;
  String? devCode;
  Timer? _timer;

  String get code => _code.text;
  String get digits => value.replaceAll(RegExp(r'\D'), '');
  String get destination => channel == 'PHONE' ? '+91$digits' : value.trim().toLowerCase();
  bool get valid => channel == 'PHONE' ? digits.length == 10 : _emailRe.hasMatch(value.trim());
  String get masked {
    if (channel == 'PHONE') return '+91 ••••••${digits.length > 4 ? digits.substring(digits.length - 4) : digits}';
    final m = RegExp(r'^(.{1,2}).*(@.*)$').firstMatch(value.trim());
    return m == null ? value.trim() : '${m.group(1)}••••${m.group(2)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => resendIn = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => resendIn = math.max(0, resendIn - 1));
      if (resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (!valid) {
      setState(() => error = channel == 'PHONE' ? tr('Enter a valid 10-digit mobile number.') : tr('Enter a valid email address.'));
      return;
    }
    if (signup && !(consent.terms && consent.adult)) {
      setState(() => consentError = true);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await AuthApi.requestOtp(channel, destination);
      devCode = res.devCode;
      _startCountdown(res.resendInSeconds);
      _code.clear();
      setState(() => stage = 'otp');
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _codeFocus.requestFocus();
      });
    } catch (e) {
      setState(() => error = e is ApiError ? e.message : tr('Couldn’t send a code. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify([String? entered]) async {
    final c = entered ?? code;
    if (c.length < _codeLength) {
      setState(() => error = tr('Enter all 6 digits.'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await AuthApi.verifyOtp(channel, destination, c);
      if (!mounted) return;
      await authOf(context).signIn(res);
      // Proof of the agreements ticked above. (New accounts made from the sign-in path are asked during onboarding.)
      if (res.newUser && signup) {
        try {
          await PrivacyApi.recordSignup();
        } catch (_) {}
      }
      AnalyticsApi.track(res.newUser ? 'signup_completed' : 'login_completed', {'channel': channel});
      // Navigation guards move the user to onboarding or the app automatically.
    } catch (e) {
      _code.clear();
      if (mounted) {
        setState(() => error = e is ApiError ? e.message : tr('That code didn’t work. Try again.'));
        _codeFocus.requestFocus();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    if (stage == 'otp') return _otp(context);
    const link = TextStyle(fontFamily: Fonts.bodyBold, color: AppColors.brand, decoration: TextDecoration.underline);
    return Screen(bottom: true, children: [
      const Header(),
      Txt(signup ? tr('CREATE YOUR ACCOUNT') : tr('WELCOME BACK'), variant: TV.kicker),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Txt(signup ? tr('How should we verify you?') : tr('Sign in to your Plans.'), variant: TV.display, style: const TextStyle(fontSize: 30)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        child: Txt(signup ? tr('Use a mobile number or email. Neither is shown on your profile.') : tr('We’ll send a one-time code—no password to remember.')),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(24, 35, 33, 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.7)),
        ),
        child: Row(children: [
          for (final c in const ['PHONE', 'EMAIL'])
            Expanded(
              child: Pressable(
                onPress: () => setState(() {
                  channel = c;
                  value = '';
                  error = null;
                }),
                selected: channel == c,
                label: c == 'PHONE' ? tr('Phone') : tr('Email'),
                focusRadius: BorderRadius.circular(11),
                builder: (_, _, _) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: channel == c
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: const [BoxShadow(color: Color.fromRGBO(12, 79, 64, 0.12), blurRadius: 8, offset: Offset(0, 3))],
                        )
                      : null,
                  child: Text(c == 'PHONE' ? tr('Phone') : tr('Email'),
                      style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 13, color: channel == c ? AppColors.ink : AppColors.inkSoft)),
                ),
              ),
            ),
        ]),
      ),
      Field(
        key: ValueKey(channel),
        label: channel == 'PHONE' ? tr('Mobile number') : tr('Email address'),
        prefix: channel == 'PHONE' ? '+91' : null,
        value: value,
        onChanged: (t) => setState(() {
          value = t;
          error = null;
        }),
        keyboardType: channel == 'PHONE' ? TextInputType.phone : TextInputType.emailAddress,
        capitalization: TextCapitalization.none,
        autocorrect: false,
        autofill: channel == 'PHONE' ? const [AutofillHints.telephoneNumberNational] : const [AutofillHints.email],
        placeholder: channel == 'PHONE' ? '98765 43210' : tr('you@example.com'),
        error: error,
        autofocus: true,
        action: TextInputAction.go,
        onSubmitted: (_) => _sendCode(),
      ),
      if (signup)
        ConsentChecks(
          value: consent,
          onChange: (v) => setState(() {
            consent = v;
            consentError = false;
            error = null;
          }),
          error: consentError,
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Txt.rich([
            TextSpan(text: tr('By continuing you agree to our ')),
            TextSpan(text: tr('Terms'), style: link, recognizer: TapGestureRecognizer()..onTap = () => Nav.push('/legal/terms')),
            TextSpan(text: tr(' and ')),
            TextSpan(text: tr('Privacy policy'), style: link, recognizer: TapGestureRecognizer()..onTap = () => Nav.push('/legal/privacy')),
            TextSpan(text: tr('.')),
          ], variant: TV.small),
        ),
      Button(tr('Continue'), iconRight: 'arrow-right', loading: busy, disabled: value.trim().isEmpty, onPress: _sendCode),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Button(
          signup ? tr('Already have an account? Sign in') : tr('New here? Create an account'),
          kind: BK.text,
          onPress: () => setState(() => signup = !signup),
        ),
      ),
    ]);
  }

  Widget _otp(BuildContext context) {
    return Screen(bottom: true, children: [
      Header(onBack: () => setState(() => stage = 'credential')),
      Txt(tr('ONE-TIME CODE'), variant: TV.kicker),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Txt(channel == 'PHONE' ? tr('Check your phone.') : tr('Check your email.'), variant: TV.display, style: const TextStyle(fontSize: 30)),
      ),
      Padding(padding: const EdgeInsets.only(top: 8), child: Txt.rich(trRich('Enter the 6-digit code sent to {destination}.', {'destination': bold(masked)}))),
      // One hidden input drives all six boxes: supports paste and SMS autofill.
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Stack(children: [
          Pressable(
            onPress: () => _codeFocus.requestFocus(),
            label: tr('6-digit code'),
            builder: (_, _, _) => Row(
              children: gapped(
                List.generate(_codeLength, (i) {
                  final active = code.length == i;
                  return Expanded(
                    child: Container(
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: error != null ? AppColors.danger : (active ? AppColors.brand : AppColors.inputBorder),
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Text(i < code.length ? code[i] : '', style: const TextStyle(fontFamily: Fonts.display, fontSize: 22, color: AppColors.ink)),
                    ),
                  );
                }),
                8,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0,
              child: Semantics(
                label: tr('One-time code'),
                child: TextField(
                  controller: _code,
                  focusNode: _codeFocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_codeLength)],
                  onChanged: (t) {
                    setState(() => error = null);
                    if (t.length == _codeLength) _verify(t);
                  },
                ),
              ),
            ),
          ),
        ]),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Banner(
            icon: 'alert-circle',
            tone: PillTone.bad,
            title: error!,
            action: channel == 'PHONE' ? tr('Change number') : tr('Change email'),
            onAction: () => setState(() => stage = 'credential'),
          ),
        ),
      Container(
        constraints: const BoxConstraints(minHeight: 48),
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: resendIn > 0
            ? Txt.rich(trRich('Resend code in {time}', {'time': bold('0:${resendIn.toString().padLeft(2, '0')}')}), variant: TV.small)
            : Button(tr('Resend code'), kind: BK.text, onPress: _sendCode),
      ),
      Button(tr('Verify and continue'), iconRight: 'arrow-right', loading: busy, disabled: code.length < _codeLength, onPress: () => _verify()),
      Padding(padding: const EdgeInsets.only(top: 16), child: Note(tr('Never share this code. Plans support will never ask for it.'), icon: 'shield')),
      if (devCode != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Txt(tr('Development build · code: {code}', {'code': devCode}), variant: TV.caption, align: TextAlign.center),
        ),
    ]);
  }
}

// ---------- Account state ----------

/// Full-screen account states from the prototype: deactivated, deletion pending, suspended.
class AccountStateScreen extends StatelessWidget {
  const AccountStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final auth = authOf(context);
    final toast = useToast(context);

    final (IconName icon, PillTone tone, String kicker, String title, String body, String primary, String? foot) = switch (me.accountStatus) {
      'DEACTIVATED' => (
          'lock',
          PillTone.neutral,
          tr('ACCOUNT DEACTIVATED'),
          tr('Your account is currently inactive'),
          tr('Your profile is hidden and people can’t discover or message you. Your data is kept.'),
          tr('Reactivate account'),
          tr('While deactivated, you can’t browse Plans or use chats.'),
        ),
      'DELETION_REQUESTED' => (
          'clock',
          PillTone.warn,
          tr('DELETION REQUESTED'),
          tr('Your account is scheduled for deletion'),
          tr('Your profile stays hidden while deletion is pending. You can cancel the request if you’ve changed your mind.'),
          tr('Cancel deletion request'),
          tr('You can cancel within the grace period set by our data policy.'),
        ),
      'SUSPENDED' => (
          'lock',
          PillTone.bad,
          tr('ACCOUNT UNAVAILABLE'),
          tr('Your account is suspended'),
          tr('You can’t use Plans while your account is suspended. If you think this is a mistake, contact support.'),
          tr('Contact support'),
          null,
        ),
      _ => ('lock', PillTone.neutral, '', '', '', '', null),
    };
    if (title.isEmpty) return const Scaffold(backgroundColor: AppColors.paper);

    Future<void> onPrimary() async {
      if (me.accountStatus == 'DEACTIVATED') {
        await showConfirm(
          context,
          title: tr('Reactivate your account?'),
          body: tr('Your profile and Plans will be visible again with your current privacy settings.'),
          okLabel: tr('Reactivate'),
          icon: 'check',
          onConfirm: () async {
            auth.setUser(await MeApi.reactivate());
            toast(tr('Welcome back. Your account is active.'));
          },
        );
      } else if (me.accountStatus == 'DELETION_REQUESTED') {
        try {
          auth.setUser(await MeApi.cancelDeletion());
          toast(tr('Deletion cancelled. Welcome back.'));
        } catch (e) {
          toast(e is ApiError ? e.message : tr('Something went wrong. Try again.'));
        }
      } else {
        // Suspended accounts can’t use in-app reporting, so contact goes by email (or the published business details).
        final to = emailOrNull(Business.supportEmail);
        if (to != null) {
          launchUrl(mailto(to, subject: 'Suspended account', body: '\n\n—\nAccount #${me.id}'));
        } else {
          Nav.push('/legal/business');
        }
      }
    }

    return Screen(bottom: true, children: [
      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Start(Logo())),
      Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Col(gap: 12, [
          Start(IconTile(icon, tone: tone, size: 56)),
          Txt(kicker, variant: TV.kicker),
          Txt(title, variant: TV.display, header: true),
          Txt(body, style: const TextStyle(fontSize: 15, height: 22 / 15)),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Col(gap: 8, [
              Button(primary, onPress: onPrimary),
              Button(tr('Sign out'), kind: BK.secondary, onPress: auth.signOut),
              Button(tr('Legal & privacy'), kind: BK.text, onPress: () => Nav.push('/legal')),
            ]),
          ),
          if (foot != null) Padding(padding: const EdgeInsets.only(top: 8), child: Txt(foot, variant: TV.small)),
        ]),
      ),
    ]);
  }
}

// ---------- Onboarding ----------

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});
  @override
  State<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  late final Me _me0 = authOf(context).user!;
  late String name = _me0.displayName == 'New member' ? '' : _me0.displayName;
  String birthYear = '';
  late String area = _me0.area ?? '';
  late String city = _me0.city ?? '';
  late String bio = _me0.bio ?? '';
  Map<String, String> errors = {};
  bool busy = false;
  // Keyboard “Next” moves through the form in order.
  final rYear = FocusNode(), rArea = FocusNode(), rCity = FocusNode(), rBio = FocusNode();
  // Accounts created from the “Sign in” path haven’t agreed to the Terms yet: ask here, before any profile data is saved.
  bool needsConsent = false;
  ConsentState consent = const ConsentState();
  bool consentError = false;

  @override
  void initState() {
    super.initState();
    PrivacyApi.consents().then((c) {
      if (mounted) setState(() => needsConsent = !c.history.any((h) => h.kind == 'TERMS' && h.granted));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final f in [rYear, rArea, rCity, rBio]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final me = authOf(context).user!;
    final e = <String, String>{};
    final year = int.tryParse(birthYear);
    final age = year == null ? null : DateTime.now().year - year;
    if (name.trim().length < 2) e['name'] = tr('Enter at least 2 characters.');
    if (birthYear.length == 4 && age != null && age < 18) {
      // Under 18: don't save the birth year or anything else; explain and offer to erase the account.
      Nav.replace('/onboarding/underage');
      return;
    }
    if (birthYear.isEmpty || year == null || age! > 100) e['birthYear'] = tr('Enter your birth year, like 2001.');
    if (needsConsent && !(consent.terms && consent.adult)) {
      consentError = true;
      e['consent'] = 'required';
    }
    if (area.trim().isEmpty) e['area'] = tr('Add an approximate area, like a neighbourhood.');
    setState(() => errors = e);
    if (e.isNotEmpty) return;
    setState(() => busy = true);
    final auth = authOf(context);
    try {
      if (needsConsent) {
        await PrivacyApi.recordSignup();
        setState(() => needsConsent = false);
      }
      auth.setUser(await MeApi.update(ProfileUpdate(
        displayName: name.trim(),
        birthYear: year,
        area: area.trim(),
        city: city.trim(),
        bio: bio.trim(),
        interests: me.interests,
        languages: me.languages.isNotEmpty ? me.languages : const ['English'],
        intents: me.intents,
      )));
      Nav.push('/onboarding/interests');
    } catch (err) {
      if (err is ApiError && err.code == 'UNDERAGE') {
        Nav.replace('/onboarding/underage');
        return;
      }
      if (mounted) {
        setState(() => errors = err is ApiError && err.fields != null ? err.fields! : {'form': err is ApiError ? err.message : tr('Couldn’t save.')});
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    return Screen(bottom: true, children: [
      Stack(alignment: Alignment.topCenter, children: [
        Header(hideBack: true, right: Txt(tr('1 of 2'), variant: TV.caption)),
        const Positioned(top: 18, child: Logo(size: 16)),
      ]),
      Txt(tr('YOUR ESSENTIALS'), variant: TV.kicker),
      Padding(padding: const EdgeInsets.only(top: 8), child: Txt(tr('Enough to make a good introduction.'), variant: TV.display, style: const TextStyle(fontSize: 28))),
      Padding(padding: const EdgeInsets.only(top: 6, bottom: 18), child: Txt(tr('No long questionnaire. You can change everything later.'))),
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          Avatar(name: name.isEmpty ? '?' : name, id: me.id, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(tr('Your initials stand in for a photo'), variant: TV.bodyStrong),
              Txt(tr('People recognise you at a Plan by your first name.'), variant: TV.small),
            ]),
          ),
        ]),
      ),
      Field(
        label: tr('Name'),
        value: name,
        onChanged: (t) => setState(() => name = t),
        autofill: const [AutofillHints.name],
        capitalization: TextCapitalization.words,
        placeholder: tr('Ananya Kapoor'),
        action: TextInputAction.next,
        onSubmitted: (_) => rYear.requestFocus(),
        error: errors['name'] ?? errors['displayName'],
      ),
      Field(
        label: tr('Birth year'),
        value: birthYear,
        onChanged: (t) => setState(() => birthYear = t),
        formatters: [digitsOnly],
        maxLength: 4,
        keyboardType: TextInputType.number,
        placeholder: '2002',
        focusNode: rYear,
        action: TextInputAction.next,
        onSubmitted: (_) => rArea.requestFocus(),
        hint: tr('Plans is 18+. Only your age range (like 22–25) is shown — never your birth year.'),
        error: errors['birthYear'],
      ),
      Field(
        label: tr('Area'),
        value: area,
        onChanged: (t) => setState(() => area = t),
        placeholder: tr('Indiranagar'),
        focusNode: rArea,
        action: TextInputAction.next,
        onSubmitted: (_) => rCity.requestFocus(),
        hint: tr('Never your exact home address.'),
        error: errors['area'],
      ),
      Field(
        label: tr('City'),
        optional: true,
        value: city,
        onChanged: (t) => setState(() => city = t),
        placeholder: tr('Bengaluru'),
        hint: tr('Helps show Plans near you.'),
        focusNode: rCity,
        action: TextInputAction.next,
        onSubmitted: (_) => rBio.requestFocus(),
      ),
      Field(
        label: tr('Short bio'),
        optional: true,
        value: bio,
        onChanged: (t) => setState(() => bio = t),
        multiline: true,
        maxLength: 300,
        focusNode: rBio,
        placeholder: tr('Product designer, weekend trekker and live music regular.'),
      ),
      if (needsConsent)
        ConsentChecks(
          value: consent,
          onChange: (v) => setState(() {
            consent = v;
            consentError = false;
          }),
          error: consentError,
        ),
      if (errors['form'] != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(liveRegion: true, child: Txt(errors['form'], variant: TV.small, style: const TextStyle(color: AppColors.dangerText))),
        ),
      Button(tr('Continue'), iconRight: 'arrow-right', loading: busy, onPress: _save),
    ]);
  }
}

class OnboardingInterestsScreen extends StatefulWidget {
  const OnboardingInterestsScreen({super.key});
  @override
  State<OnboardingInterestsScreen> createState() => _OnboardingInterestsScreenState();
}

class _OnboardingInterestsScreenState extends State<OnboardingInterestsScreen> {
  late final Me _me0 = authOf(context).user!;
  late List<String> interests = [..._me0.interests];
  late List<String> chosenIntents = [..._me0.intents];
  bool busy = false;
  String error = '';

  List<V> _toggle<V>(List<V> list, V v) => list.contains(v) ? list.where((x) => x != v).toList() : [...list, v];

  Future<void> _finish() async {
    final auth = authOf(context);
    final me = auth.user!;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await MeApi.update(ProfileUpdate(
        displayName: me.displayName,
        area: me.area ?? '',
        city: me.city,
        bio: me.bio,
        interests: interests,
        languages: me.languages,
        intents: chosenIntents,
      ));
      auth.setUser(await MeApi.completeOnboarding());
      AnalyticsApi.track('onboarding_completed', {'interests': interests.length});
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Screen(bottom: true, children: [
      Header(right: Txt(tr('2 of 2'), variant: TV.caption)),
      Txt(tr('PERSONALISE DISCOVERY'), variant: TV.kicker),
      Padding(padding: const EdgeInsets.only(top: 8), child: Txt(tr('What would you actually show up for?'), variant: TV.display, style: const TextStyle(fontSize: 28))),
      Padding(padding: const EdgeInsets.only(top: 6), child: Txt(tr('Pick a few. Plans—not profile labels—drive your experience.'))),
      SectionTitle(tr('Interests')),
      ChipWrap(interestsList.map((i) => Chip(i, selected: interests.contains(i), onPress: () => setState(() => interests = _toggle(interests, i)))).toList()),
      SectionTitle(tr('Open to (optional)')),
      ChipWrap(intents
          .map((i) => Chip(i.label, selected: chosenIntents.contains(i.value), onPress: () => setState(() => chosenIntents = _toggle(chosenIntents, i.value))))
          .toList()),
      Padding(padding: const EdgeInsets.only(top: 8), child: Txt(tr('Dating is optional and never required. Plans is about shared real-world activities.'), variant: TV.small)),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Note(tr('Your choices improve discovery. They’re never used to expose private contact or location details.')),
      ),
      if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Txt(error, variant: TV.small, style: const TextStyle(color: Color(0xFFB94343)))),
      Button(tr('Explore plans'), iconRight: 'arrow-right', loading: busy, disabled: interests.isEmpty, onPress: _finish),
    ]);
  }
}

/// Plans is for adults. Someone under 18 can't continue, and we don't keep their details: one tap erases the account
/// straight away (no grace period) and signs them out. Their birth year was never saved.
class UnderageScreen extends StatefulWidget {
  const UnderageScreen({super.key});
  @override
  State<UnderageScreen> createState() => _UnderageScreenState();
}

class _UnderageScreenState extends State<UnderageScreen> {
  bool busy = false;
  String? error;

  Future<void> _erase() async {
    final auth = authOf(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await PrivacyApi.deleteUnderage();
      await auth.signOut();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is ApiError ? e.message : tr('Couldn’t delete your details. Try again.');
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return PopScope(
      canPop: false,
      child: Screen(bottom: true, children: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Start(Logo())),
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Col(gap: 12, [
            const Start(IconTile('user-x', tone: PillTone.neutral, size: 56)),
            Txt(tr('ADULTS ONLY'), variant: TV.kicker),
            Txt(tr('Plans is for people aged 18 and over'), variant: TV.display, header: true),
            Txt(
              tr('Because Plans helps people meet in person, we only allow adults. We haven’t saved your birth year, and we’ll delete the sign-in details you gave us now.'),
              style: const TextStyle(fontSize: 15, height: 22 / 15),
            ),
            if (error != null) Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!),
            Padding(padding: const EdgeInsets.only(top: 10), child: Button(tr('Delete my details and exit'), onPress: _erase, loading: busy)),
            Note(tr('Entered the wrong year by mistake? Deleting now means you can sign up again with the correct one.'), icon: 'info'),
          ]),
        ),
      ]),
    );
  }
}
