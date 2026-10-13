import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:plans/api/client.dart';
import 'package:plans/api/types.dart';
import 'package:plans/app.dart';
import 'package:plans/i18n/i18n.dart';
import 'package:plans/nav.dart';
import 'package:plans/state/auth.dart';
import 'package:plans/state/toast.dart';

import 'fake_api.dart';
import 'fixtures.dart';

/// Opens the app on a phone-sized screen with a fake backend, as the given user (or signed out).
Future<void> openApp(WidgetTester tester, {Me? user, String lang = 'en'}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  setHttpClient(fakeBackend());
  FlutterSecureStorage.setMockInitialValues({});
  // Print layout errors while the widgets still exist, so the report names them.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('LIVE ERROR: ${details.toString()}');
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  final i18n = I18n();
  if (lang != 'en') i18n.setLang(lang);
  final auth = AuthState()
    ..ready = true
    ..user = user;

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: i18n),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => ToastController()),
    ],
    child: PlansApp(auth: auth),
  ));
  await settle(tester);
}

/// Lets requests resolve and entry animations finish (screens never truly "settle" while a spinner runs).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void noErrors(WidgetTester tester) {
  // Uncaught Flutter errors (overflows, bad constraints) fail the test by themselves, with full diagnostics.
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

Future<void> go(WidgetTester tester, String location) async {
  Nav.router.go(location);
  await settle(tester);
}

/// Unmounts the app so chat sockets, polls and timers are disposed before the test ends.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

const signedInRoutes = [
  '/', '/plans', '/chats', '/me',
  '/plan/new', '/plan/5', '/plan/8', '/plan/5/edit', '/plan/5/announce',
  '/chat/20', '/group/21', '/request/40', '/user/12', '/organizer/3', '/organizer/setup', '/search',
  '/report?targetType=PROFILE&targetId=12&title=Nisha%E2%80%99s%20profile&personId=12&personName=Nisha&quote=hello',
  '/report?targetType=PROBLEM&title=A%20problem',
  '/edit-profile', '/help', '/unavailable?reason=plan', '/unavailable',
  '/notifications', '/notifications/settings',
  '/safety', '/safety/blocked', '/safety/guidelines', '/safety/visibility', '/safety/reports', '/safety/reports/30',
  '/verify', '/verify/email', '/verify/identity', '/verify/organizer', '/verify/phone',
  '/settings', '/settings/account', '/settings/privacy', '/settings/fields', '/settings/location', '/settings/discover',
  '/settings/howPrivacy', '/settings/security', '/settings/recovery', '/settings/lifecycle', '/settings/deactivate',
  '/settings/delete', '/settings/content', '/settings/restricted', '/settings/nope',
  '/settings/choice/language', '/settings/choice/messages', '/settings/choice/connectionRequests',
  '/settings/contact/EMAIL', '/settings/contact/PHONE',
  '/settings/data', '/settings/delete-confirm', '/settings/name', '/settings/password', '/settings/secActivity', '/settings/sessions',
  '/legal', '/legal/privacy', '/legal/business', '/legal/licenses', '/legal/accessibility',
];

void main() {
  for (final lang in ['en', 'hi']) {
    group('signed in [$lang]', () {
      for (final route in signedInRoutes) {
        testWidgets(route, (tester) async {
          await openApp(tester, user: fakeMe(language: lang), lang: lang);
          await go(tester, route);
          noErrors(tester);
          expect(find.byType(Scaffold), findsWidgets);
          await closeApp(tester);
        });
      }
    });

    group('signed out [$lang]', () {
      for (final route in ['/welcome', '/sign-in?mode=signup', '/sign-in?mode=login', '/legal', '/legal/terms']) {
        testWidgets(route, (tester) async {
          await openApp(tester, lang: lang);
          await go(tester, route);
          noErrors(tester);
          await closeApp(tester);
        });
      }
    });

    group('onboarding [$lang]', () {
      for (final route in ['/onboarding/profile', '/onboarding/interests', '/onboarding/underage']) {
        testWidgets(route, (tester) async {
          await openApp(tester, user: fakeMe(onboarded: false, language: lang), lang: lang);
          await go(tester, route);
          noErrors(tester);
          await closeApp(tester);
        });
      }
    });

    group('account states [$lang]', () {
      for (final status in ['DEACTIVATED', 'DELETION_REQUESTED', 'SUSPENDED']) {
        testWidgets(status, (tester) async {
          await openApp(tester, user: fakeMe(accountStatus: status, language: lang), lang: lang);
          expect(Nav.router.state.uri.path, '/account-state');
          noErrors(tester);
          await closeApp(tester);
        });
      }
    });
  }

  group('guards (Stack.Protected)', () {
    testWidgets('signed out → welcome, app routes are not reachable', (tester) async {
      await openApp(tester);
      expect(Nav.router.state.uri.path, '/welcome');
      await go(tester, '/settings');
      expect(Nav.router.state.uri.path, '/welcome');
      await go(tester, '/legal/privacy');
      expect(Nav.router.state.uri.path, '/legal/privacy');
      await closeApp(tester);
    });

    testWidgets('signed in but not onboarded → onboarding', (tester) async {
      await openApp(tester, user: fakeMe(onboarded: false));
      expect(Nav.router.state.uri.path, '/onboarding/profile');
      await go(tester, '/');
      expect(Nav.router.state.uri.path, '/onboarding/profile');
      await closeApp(tester);
    });

    testWidgets('onboarded → Discover; welcome is not reachable', (tester) async {
      await openApp(tester, user: fakeMe());
      expect(Nav.router.state.uri.path, '/');
      await go(tester, '/welcome');
      expect(Nav.router.state.uri.path, '/');
      expect(find.text('Nearby plans'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('signing out returns to welcome', (tester) async {
      await openApp(tester, user: fakeMe());
      await go(tester, '/settings');
      final auth = tester.element(find.byType(Scaffold).first).read<AuthState>();
      unawaited(auth.signOut());
      await settle(tester);
      expect(Nav.router.state.uri.path, '/welcome');
      noErrors(tester);
      await closeApp(tester);
    });
  });

  group('interactions', () {
    testWidgets('tabs switch and the badge shows unread chats', (tester) async {
      await openApp(tester, user: fakeMe());
      expect(find.text('9+'), findsOneWidget); // 12 unread conversations
      await tester.tap(find.text('Chats').last);
      await settle(tester);
      expect(Nav.router.state.uri.path, '/chats');
      expect(find.text('Plan groups'.toUpperCase()), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await settle(tester);
      expect(Nav.router.state.uri.path, '/me');
      await closeApp(tester);
    });

    testWidgets('plan detail: menu sheet opens and closes', (tester) async {
      await openApp(tester, user: fakeMe());
      await go(tester, '/');
      Nav.push('/plan/5');
      await settle(tester);
      expect(find.text('What changed'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('More options for this Plan'));
      await settle(tester);
      expect(find.text('Share'), findsWidgets);
      await tester.tap(find.text('Cancel').last);
      await settle(tester);
      noErrors(tester);
      await closeApp(tester);
    });

    testWidgets('leave Plan asks for confirmation', (tester) async {
      await openApp(tester, user: fakeMe());
      Nav.push('/plan/5');
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Joined · Leave Plan'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Joined · Leave Plan'));
      await settle(tester);
      expect(find.text('Leave this Plan?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await settle(tester);
      expect(find.text('Leave this Plan?'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('report flow: reason → details → submitted', (tester) async {
      await openApp(tester, user: fakeMe());
      Nav.push('/report', {'targetType': 'PLAN', 'targetId': '5', 'title': 'Walk'});
      await settle(tester);
      await tapText(tester, 'Spam');
      await settle(tester);
      await tapText(tester, 'Continue');
      await settle(tester);
      expect(find.textContaining('Tell us more', findRichText: true), findsOneWidget);
      await tapText(tester, 'Submit report');
      await settle(tester);
      expect(find.text('Report submitted'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('chat shows the unread divider once, above the first unread message', (tester) async {
      await openApp(tester, user: fakeMe());
      Nav.push('/chat/20');
      await settle(tester);
      expect(find.text('2 new messages'), findsOneWidget);
      expect(find.text('See you at the bandstand! Bring a spare battery if you have one.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('sign-in validates the phone number before sending', (tester) async {
      await openApp(tester);
      await go(tester, '/sign-in?mode=login');
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.pump();
      await tapText(tester, 'Continue');
      await settle(tester);
      expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('language picker switches the welcome screen to Hindi', (tester) async {
      await openApp(tester);
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.text('हिन्दी'));
      await settle(tester);
      expect(find.text('Get started'), findsNothing);
      expect(find.text(tr('Get started', null, 'hi')), findsOneWidget);
      await closeApp(tester);
    });
  });
}
