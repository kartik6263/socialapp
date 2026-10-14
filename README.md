# Plans — mobile app (Flutter)

The Plans app for Android and iOS. It was converted from the earlier React Native / Expo app (still in git history,
commit `d6adbfc`) and talks to the same Spring Boot API in `../backend`.

## Run

Requires the Flutter SDK (stable, Dart 3.12+) and, for Android, the Android SDK with a full JDK 17–21.

```bash
flutter pub get
flutter run                                   # default API: http://10.0.2.2:8080 (host machine, from the Android emulator)
flutter run --dart-define=API_URL=http://192.168.1.20:8080   # a real phone on your Wi-Fi
flutter build apk --release --dart-define=API_URL=https://api.example.com
```

Debug builds allow plain HTTP to the local backend; release builds are HTTPS-only.

## Checks

```bash
flutter analyze      # static analysis — must report no issues
flutter test         # logic tests + every screen rendered in English and Hindi against a fake backend
```

## Push notifications

Push uses Firebase Cloud Messaging (Android) and APNs via Firebase (iOS). Add the platform config files before
release (`flutterfire configure`, or place `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`).
Without them the app works normally and push stays off — the same as the Expo app, which had no Firebase config.

## Structure (`lib/`)

| Path | What |
| --- | --- |
| `app.dart` | Router (`go_router`): every route, the sign-in / onboarding / account-state guards, session start-up |
| `nav.dart` | `Nav.push / replace / navigate / goBack` — the old `router` helpers |
| `api/` | Typed models (`types.dart`), HTTP client with single-flight token refresh (`client.dart`), endpoints (`api.dart`) |
| `state/` | Auth, toasts, screen data loading (`focus_data.dart`), chat realtime + optimistic sends (`conversation.dart`) |
| `i18n/` | `tr()`, `translateServer()`, `trRich()` and the Hindi / Kannada dictionaries, keyed by the English text |
| `widgets/` | Design system: `ui.dart` (Txt, Button, Pill, Group, ListRow, Field…), sheets & dialogs, glass, plan cards |
| `screens/` | One file per area: auth, tabs, plan, chat, people, report, notifications, safety, verify, settings, legal |
| `util/` | Date formatting, categories, deep links, privacy choices, business details, push |

Translations: wrap new text in `tr('English text')` and add the same key to `lib/i18n/hi.dart` and `kn.dart`.
Business details shown in the app live in `lib/util/misc.dart` (`Business`) — fill them in before launch.
Colours: run `node scripts/contrast.mjs` after changing them (WCAG AA check against the glass surfaces).

## Contributing

- The Flutter app lives on `main`. Branch from it.
- One branch per ticket, named after the ticket ID, for example `payp-051-ios-push-token`.
- Open a pull request into `main`. CI (`.github/workflows/ci.yml`)
  runs `flutter pub get`, `flutter analyze` and `flutter test` on Flutter 3.47.7 and must pass before merging.
- Follow `AGENTS.md`: all text through `tr()` with Hindi and Kannada entries, design-system widgets, and a fake-API
  fixture for every new endpoint.
- Dependabot opens weekly update pull requests for pub packages and GitHub Actions.
