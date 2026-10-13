import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'api/api.dart';
import 'i18n/i18n.dart';
import 'nav.dart';
import 'screens/auth.dart';
import 'screens/chat.dart';
import 'screens/legal.dart';
import 'screens/notifications.dart';
import 'screens/people.dart';
import 'screens/plan.dart';
import 'screens/report.dart';
import 'screens/safety.dart';
import 'screens/settings.dart';
import 'screens/tabs.dart';
import 'screens/verify.dart';
import 'state/auth.dart';
import 'state/focus_data.dart';
import 'state/toast.dart';
import 'theme.dart';
import 'util/push.dart';
import 'widgets/privacy_choices.dart';

/// Restricted accounts can still use the app (with limits); these three states get a dedicated screen.
const _blockedStates = {'DEACTIVATED', 'DELETION_REQUESTED', 'SUSPENDED'};

Page<void> _page(GoRouterState s, Widget child, {bool modal = false}) =>
    MaterialPage<void>(key: s.pageKey, name: s.uri.path, fullscreenDialog: modal, child: child);

int _id(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
String? _q(GoRouterState s, String key) {
  final v = s.uri.queryParameters[key];
  return v == null || v.isEmpty ? null : v;
}

GoRoute _r(String path, Widget Function(GoRouterState s) build, {bool modal = false}) => GoRoute(
      path: path,
      parentNavigatorKey: Nav.rootKey,
      pageBuilder: (context, s) => _page(s, build(s), modal: modal),
    );

GoRouter buildRouter(AuthState auth) {
  final router = GoRouter(
    navigatorKey: Nav.rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    observers: [routeObserver],
    redirect: (context, state) {
      final loc = state.uri.path;
      if (!auth.ready) return loc == '/splash' ? null : '/splash';
      final legal = loc == '/legal' || loc.startsWith('/legal/');
      final u = auth.user;
      final signedIn = u != null;
      final blocked = signedIn && _blockedStates.contains(u.accountStatus);
      final onboarded = u?.onboarded ?? false;

      final bool allowed;
      final String home;
      if (!signedIn) {
        allowed = loc == '/welcome' || loc == '/sign-in' || legal;
        home = '/welcome';
      } else if (blocked) {
        allowed = loc == '/account-state' || legal;
        home = '/account-state';
      } else if (!onboarded) {
        allowed = loc.startsWith('/onboarding/') || legal;
        home = '/onboarding/profile';
      } else {
        allowed = !(loc == '/splash' || loc == '/welcome' || loc == '/sign-in' || loc == '/account-state' || loc.startsWith('/onboarding/'));
        home = '/';
      }
      return allowed ? null : home;
    },
    routes: [
      _r('/splash', (_) => const SplashScreen()),
      _r('/welcome', (_) => const WelcomeScreen()),
      _r('/sign-in', (s) => SignInScreen(mode: _q(s, 'mode'))),
      _r('/account-state', (_) => const AccountStateScreen()),
      _r('/onboarding/profile', (_) => const OnboardingProfileScreen()),
      _r('/onboarding/interests', (_) => const OnboardingInterestsScreen()),
      _r('/onboarding/underage', (_) => const UnderageScreen()),

      // Policies and business details are readable by everyone, signed in or not.
      _r('/legal', (_) => const LegalHubScreen()),
      _r('/legal/business', (_) => const BusinessDetailsScreen()),
      _r('/legal/licenses', (_) => const LicensesScreen()),
      _r('/legal/accessibility', (_) => const AccessibilityScreen()),
      _r('/legal/:slug', (s) => LegalPageScreen(slug: s.pathParameters['slug']!)),

      StatefulShellRoute(
        parentNavigatorKey: Nav.rootKey,
        builder: (context, state, shell) => TabsShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) => IndexedStack(
          index: shell.currentIndex,
          children: [for (var i = 0; i < children.length; i++) TabFocus(tick: tabTicks[i], child: children[i])],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const DiscoverScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/plans', pageBuilder: (c, s) => _page(s, const MyPlansScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/chats', pageBuilder: (c, s) => _page(s, const ChatsScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/me', pageBuilder: (c, s) => _page(s, const MyProfileScreen()))]),
        ],
      ),

      _r('/plan/new', (s) => CreatePlanScreen(from: _q(s, 'from'), draft: _q(s, 'draft')), modal: true),
      _r('/plan/:id', (s) => PlanDetailScreen(id: _id(s), from: _q(s, 'from'), mode: _q(s, 'mode'))),
      _r('/plan/:id/edit', (s) => EditDetailsScreen(id: _id(s))),
      _r('/plan/:id/announce', (s) => AnnouncementScreen(id: _id(s))),
      _r('/chat/:id', (s) => DirectChatScreen(id: _id(s))),
      _r('/group/:id', (s) => PlanGroupScreen(id: _id(s))),
      _r('/request/:id', (s) => ConnectionRequestScreen(id: _id(s))),
      _r('/user/:id', (s) => PersonProfileScreen(id: _id(s))),
      _r('/organizer/setup', (_) => const OrganizerSetupScreen()),
      _r('/organizer/:id', (s) => OrganizerProfileScreen(id: _id(s))),
      _r('/search', (_) => const SearchScreen()),
      _r('/report', (s) => ReportFlowScreen(params: s.uri.queryParameters), modal: true),
      _r('/edit-profile', (_) => const EditProfileScreen()),
      _r('/help', (_) => const HelpScreen()),
      _r('/unavailable', (s) => UnavailableScreen(reason: _q(s, 'reason'))),
      _r('/notifications', (_) => const NotificationsScreen()),
      _r('/notifications/settings', (_) => const NotificationSettingsScreen()),
      _r('/safety', (_) => const SafetyCenterScreen()),
      _r('/safety/blocked', (_) => const BlockedPeopleScreen()),
      _r('/safety/guidelines', (_) => const GuidelinesScreen()),
      _r('/safety/visibility', (_) => const WhatOthersSeeScreen()),
      _r('/safety/reports', (_) => const YourReportsScreen()),
      _r('/safety/reports/:id', (s) => ReportDetailScreen(id: _id(s))),
      _r('/verify', (_) => const VerificationCenterScreen()),
      _r('/verify/email', (_) => const EmailVerificationScreen()),
      _r('/verify/identity', (_) => const IdentityVerificationScreen()),
      _r('/verify/organizer', (_) => const OrganizerVerificationScreen()),
      _r('/verify/phone', (_) => const PhoneVerificationScreen()),
      _r('/settings', (_) => const SettingsHomeScreen()),
      _r('/settings/data', (_) => const YourDataScreen()),
      _r('/settings/delete-confirm', (_) => const DeleteConfirmScreen()),
      _r('/settings/name', (_) => const ChangeNameScreen()),
      _r('/settings/password', (_) => const ChangePasswordScreen()),
      _r('/settings/secActivity', (_) => const SecurityActivityScreen()),
      _r('/settings/sessions', (_) => const SessionsScreen()),
      _r('/settings/choice/:key', (s) => ChoiceScreen(choiceKey: s.pathParameters['key']!)),
      _r('/settings/contact/:channel', (s) => ChangeContactScreen(channel: s.pathParameters['channel']!)),
      _r('/settings/:page', (s) => SettingsPageScreen(page: s.pathParameters['page']!)),
    ],
  );
  Nav.router = router;
  return router;
}

class PlansApp extends StatefulWidget {
  final AuthState auth;
  const PlansApp({super.key, required this.auth});

  @override
  State<PlansApp> createState() => _PlansAppState();
}

class _PlansAppState extends State<PlansApp> {
  late final GoRouter _router = buildRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return MaterialApp.router(
      title: 'Plans',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: AppSession(child: Stack(children: [child ?? const SizedBox(), const ToastOverlay()])),
      ),
    );
  }
}

/// Session-wide effects: keeps the app language and the account's language setting in step, and once the
/// signed-in app opens, sets up push and asks the privacy-choices question.
class AppSession extends StatefulWidget {
  final Widget child;
  const AppSession({super.key, required this.child});

  @override
  State<AppSession> createState() => _AppSessionState();
}

class _AppSessionState extends State<AppSession> {
  String? _syncKey;
  bool _appStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthState>(context);
    final i18n = Provider.of<I18n>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      _syncKey = null;
      if (_appStarted) resetPrivacyChoices();
      _appStarted = false;
      return;
    }

    // Language: the account is the source of truth across devices once onboarded;
    // a language picked on the welcome screen carries into a new account.
    final key = '${user.id}|${user.onboarded}|${user.privacy.language}';
    if (key != _syncKey) {
      _syncKey = key;
      final server = user.privacy.language;
      if (user.onboarded) {
        if (server != i18n.lang) WidgetsBinding.instance.addPostFrameCallback((_) => i18n.setLang(server));
      } else if (server != i18n.lang) {
        MeApi.updatePrivacy({'language': i18n.lang}).then(auth.setUser).catchError((_) {});
      }
    }

    final inApp = user.onboarded && !_blockedStates.contains(user.accountStatus);
    if (inApp && !_appStarted) {
      _appStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await initPush();
        // Refresh the device token on every launch once permission exists (tokens rotate).
        if (await getPushPermission() == 'granted') await enablePush();
        await checkPrivacyChoices();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
