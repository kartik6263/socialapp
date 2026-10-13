import 'package:flutter/material.dart';

// Design tokens taken from the "Social Discovery App Design" prototype.
class AppColors {
  static const ink = Color(0xFF182321);
  static const inkSoft = Color(0xFF53635F);
  static const paper = Color(0xFFF7F8F4);

  /// Frosted glass fill for cards and groups (see Glass.fill). Use surfaceSolid where something must be opaque.
  static const surface = Color.fromRGBO(255, 255, 255, 0.72);
  static const surfaceSolid = Color(0xFFFFFFFF);

  /// Soft edge between glass pieces.
  static const line = Color.fromRGBO(24, 35, 33, 0.1);

  /// Outline for inputs and checkboxes: 3.4:1 on white, meeting WCAG 1.4.11 for controls.
  static const inputBorder = Color(0xFF74847E);
  static const brand = Color(0xFF126B55);
  static const brandDark = Color(0xFF0C4F40);
  static const brandPale = Color(0xFFE0F1E9);
  static const lime = Color(0xFFDFF060);
  static const violet = Color(0xFF7156D9);
  static const danger = Color(0xFFB94343);

  /// Error text that sits straight on the backdrop (under inputs): darker than danger for 4.5:1.
  static const dangerText = Color(0xFF9A3030);
  static const badge = Color(0xFFC94E4E);

  /// Switch off-state: 3:1 against the backdrop so "off" is visible, not just faint.
  static const track = Color(0xFF8B9993);
  static const divider = Color.fromRGBO(24, 35, 33, 0.07);
  static const frame = Color(0xFFECEEE9);
  static const dangerPale = Color(0xFFF8E5E5);
  static const warning = Color(0xFF9B5D2D);
  static const warningPale = Color(0xFFF7ECDF);
  static const muted = Color(0xFFEDF0EC);
}

class Tone {
  final Color bg;
  final Color fg;
  const Tone(this.bg, this.fg);
}

enum AvatarTone { mint, violet, coral, blue }

const Map<AvatarTone, Tone> avatarTones = {
  AvatarTone.mint: Tone(Color(0xFFBCE0D0), Color(0xFF315849)),
  AvatarTone.violet: Tone(Color(0xFFD7CFF0), Color(0xFF49377A)),
  AvatarTone.coral: Tone(Color(0xFFEFC5B4), Color(0xFF714433)),
  AvatarTone.blue: Tone(Color(0xFFBFDAE6), Color(0xFF28556B)),
};

/// Status pills used across verification, reports and settings.
enum PillTone { ok, neutral, blue, warn, bad, ink, lime }

const Map<PillTone, Tone> pills = {
  PillTone.ok: Tone(Color(0xFFE0F1E9), Color(0xFF126B55)),
  PillTone.neutral: Tone(Color(0xFFEEF1EE), Color(0xFF3D4A47)),
  PillTone.blue: Tone(Color(0xFFE0EDF2), Color(0xFF2B5C74)),
  PillTone.warn: Tone(Color(0xFFFFF0CB), Color(0xFF795F27)),
  PillTone.bad: Tone(Color(0xFFFAEAEA), Color(0xFFB94343)),
  PillTone.ink: Tone(Color(0xFF182321), Color(0xFFFFFFFF)),
  PillTone.lime: Tone(Color(0xFFDFF060), Color(0xFF182321)),
};

/// Each weight is bundled as its own family, named like the React Native app's fonts.
class Fonts {
  static const display = 'Manrope_800ExtraBold';
  static const displayBold = 'Manrope_700Bold';
  static const body = 'DMSans_400Regular';
  static const bodyMedium = 'DMSans_500Medium';
  static const bodySemi = 'DMSans_600SemiBold';
  static const bodyBold = 'DMSans_700Bold';
}

class Radii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

const cardShadow = [BoxShadow(color: Color.fromRGBO(28, 48, 41, 0.07), blurRadius: 18, offset: Offset(0, 6))];

/// Glass surfaces. Fills stay mostly opaque on purpose: text sits on them, and every text colour keeps
/// WCAG AA contrast (≥4.5:1) against the fill composited over the brightest part of the backdrop.
class GlassTokens {
  static const fill = Color.fromRGBO(255, 255, 255, 0.72);
  static const fillStrong = Color.fromRGBO(255, 255, 255, 0.88);
  static const fillSoft = Color.fromRGBO(255, 255, 255, 0.5);
  static const border = Color.fromRGBO(255, 255, 255, 0.9);
  static const hairline = Color.fromRGBO(24, 35, 33, 0.08);
  static const pressed = Color.fromRGBO(224, 241, 233, 0.9);

  /// Light catching the top edge of the glass.
  static const highlight = Color.fromRGBO(255, 255, 255, 0.95);
  static const shadow = [BoxShadow(color: Color.fromRGBO(12, 79, 64, 0.1), blurRadius: 24, offset: Offset(0, 10))];
}

/// The aurora behind every screen: morning light over a park, where Plans happen.
/// Brand mint at the top, a lime sun, a soft violet dusk at the bottom. Kept pale so glass stays readable.
class Aurora {
  static const base = [Color(0xFFF4F8F2), Color(0xFFEEF6F1), Color(0xFFF3F1FA)];
  static const mint = Color.fromRGBO(129, 206, 170, 0.32);
  static const lime = Color.fromRGBO(223, 240, 96, 0.35);
  static const violet = Color.fromRGBO(170, 152, 235, 0.2);
}

/// Primary action fill: a little depth so the main button reads as the next step.
const brandGradient = [Color(0xFF178066), Color(0xFF0E5C49)];

/// Placeholder text: darker than the old #8a9893 so it passes 4.5:1 on inputs.
const placeholderColor = Color(0xFF5C6B65);

class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 420);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: Fonts.body,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand, primary: AppColors.brand, surface: AppColors.paper),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.brand, selectionHandleColor: AppColors.brand),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
