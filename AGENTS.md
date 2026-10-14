This is a Flutter mobile app (Android + iOS) for Plans. It was converted from React Native / Expo; that code is in
git history only.

## Commands

```bash
flutter pub get
flutter analyze        # must report "No issues found"
flutter test           # must pass; screens_test.dart renders every route in English and Hindi
flutter build apk --debug
```

Run analyze and test before declaring any task done.

## Conventions

- Routes are declared in `lib/app.dart`; navigate with `Nav` (`lib/nav.dart`), not `Navigator` directly.
- Screens that load data mix in `FocusData` (`lib/state/focus_data.dart`) so they refresh when shown again.
- All user-visible text goes through `tr()`; keys are the English text, translated in `lib/i18n/hi.dart` / `kn.dart`.
- Call `useLanguage(context)` at the top of a screen's `build` so it re-renders when the language changes.
- Use the design-system widgets in `lib/widgets/ui.dart` (they shadow Material's `Card`, `Chip`, `Switch`, `Banner`;
  import Material with `hide Card, Chip, Switch, Banner`).
- Icons are Feather names (`FIcon('map-pin')`), from the bundled Feather font.
- New endpoints: add the model to `lib/api/types.dart`, the call to `lib/api/api.dart`, and a fixture to
  `test/fake_api.dart` so the screen test renders it with data.
