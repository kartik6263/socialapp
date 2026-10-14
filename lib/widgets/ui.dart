import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:flutter/services.dart';

import '../api/client.dart' show ApiError;
import '../api/types.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../theme.dart';
import '../util/format.dart';
import 'glass.dart';
import 'icons.dart';
import 'motion.dart';

export '../theme.dart';
export 'icons.dart';
export 'motion.dart' show Appear, Pressable, reducedMotion;

// ---------- Typography ----------

enum TV { display, title, heading, body, bodyStrong, small, kicker, caption, section }

TextStyle _ts(String family, double size, {double? lineHeight, double letterSpacing = 0, Color color = AppColors.ink}) => TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight == null ? null : lineHeight / size,
      letterSpacing: letterSpacing,
      color: color,
      decoration: TextDecoration.none,
    );

final Map<TV, TextStyle> textStyles = {
  TV.display: _ts(Fonts.display, 32, lineHeight: 36, letterSpacing: -1.2),
  TV.title: _ts(Fonts.display, 24, lineHeight: 29, letterSpacing: -0.7),
  TV.heading: _ts(Fonts.display, 18, lineHeight: 23, letterSpacing: -0.4),
  TV.body: _ts(Fonts.body, 14, lineHeight: 21, color: AppColors.inkSoft),
  TV.bodyStrong: _ts(Fonts.bodyBold, 14, lineHeight: 19),
  TV.small: _ts(Fonts.body, 12, lineHeight: 17, color: AppColors.inkSoft),
  TV.kicker: _ts(Fonts.bodyBold, 10, letterSpacing: 1.3, color: AppColors.brand),
  TV.caption: _ts(Fonts.bodyMedium, 11, lineHeight: 15, color: AppColors.inkSoft),
  TV.section: _ts(Fonts.bodyBold, 11, letterSpacing: 1.2, color: AppColors.brand),
};

/// Text in one of the app's type styles. Pass `spans` for nested styled runs (bold names, links).
class Txt extends StatelessWidget {
  final String? text;
  final List<InlineSpan>? spans;
  final TV variant;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? align;
  final bool header;
  final String? semanticsLabel;
  const Txt(this.text, {super.key, this.variant = TV.body, this.style, this.maxLines, this.align, this.header = false, this.semanticsLabel})
      : spans = null;
  const Txt.rich(this.spans, {super.key, this.variant = TV.body, this.style, this.maxLines, this.align, this.header = false, this.semanticsLabel})
      : text = null;

  @override
  Widget build(BuildContext context) {
    final s = textStyles[variant]!.merge(style);
    final overflow = maxLines != null ? TextOverflow.ellipsis : null;
    Widget w = spans != null
        ? Text.rich(TextSpan(children: spans), style: s, maxLines: maxLines, overflow: overflow, textAlign: align, semanticsLabel: semanticsLabel)
        : Text(text ?? '', style: s, maxLines: maxLines, overflow: overflow, textAlign: align, semanticsLabel: semanticsLabel);
    if (variant == TV.section) w = Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: w);
    if (header) w = Semantics(header: true, child: w);
    return w;
  }
}

TextSpan bold(String text, {Color color = AppColors.ink}) => TextSpan(text: text, style: TextStyle(fontFamily: Fonts.bodyBold, color: color));

/// Headline with an accent-coloured trailing phrase: "Discover who else is *doing it.*"
class Headline extends StatelessWidget {
  final String text;
  final String? accent;
  final TV size;
  const Headline({super.key, required this.text, this.accent, this.size = TV.display});

  @override
  Widget build(BuildContext context) {
    return Txt.rich(
      [TextSpan(text: text), if (accent != null) TextSpan(text: accent, style: const TextStyle(color: AppColors.brand))],
      variant: size,
      header: true,
    );
  }
}

/// Lets a child keep its own width inside a stretched column (alignSelf: 'flex-start').
class Start extends StatelessWidget {
  final Widget child;
  const Start(this.child, {super.key});
  @override
  Widget build(BuildContext context) => Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: child);
}

class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

/// Children with a fixed gap between them, like a flex view with `gap`.
List<Widget> gapped(Iterable<Widget> children, double gap) {
  final out = <Widget>[];
  for (final c in children) {
    if (out.isNotEmpty) out.add(SizedBox(width: gap, height: gap));
    out.add(c);
  }
  return out;
}

class Col extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;
  const Col(this.children, {super.key, this.gap = 0, this.cross = CrossAxisAlignment.stretch});
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: cross, children: gapped(children, gap));
}

class Rw extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;
  final MainAxisAlignment main;
  const Rw(this.children, {super.key, this.gap = 0, this.cross = CrossAxisAlignment.center, this.main = MainAxisAlignment.start});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: cross, mainAxisAlignment: main, children: gapped(children, gap));
}

// ---------- Buttons ----------

enum BK { primary, secondary, text, danger, dangerSolid, ink }

class Button extends StatelessWidget {
  final String label;
  final VoidCallback? onPress;
  final BK kind;
  final IconName? icon;
  final IconName? iconRight;
  final bool disabled;
  final bool loading;
  final bool compact;
  final String? a11yLabel;
  final String? a11yHint;
  const Button(
    this.label, {
    super.key,
    this.onPress,
    this.kind = BK.primary,
    this.icon,
    this.iconRight,
    this.disabled = false,
    this.loading = false,
    this.compact = false,
    this.a11yLabel,
    this.a11yHint,
  });

  @override
  Widget build(BuildContext context) {
    final fg = switch (kind) {
      BK.primary || BK.dangerSolid || BK.ink => Colors.white,
      BK.danger => AppColors.danger,
      BK.text => AppColors.brand,
      BK.secondary => AppColors.ink,
    };
    final bg = switch (kind) {
      BK.primary => AppColors.brand,
      BK.secondary || BK.danger => GlassTokens.fillStrong,
      BK.text => Colors.transparent,
      BK.dangerSolid => AppColors.danger,
      BK.ink => AppColors.ink,
    };
    final off = disabled || loading;
    final radius = compact ? 11.0 : Radii.md;
    final bordered = kind == BK.secondary || kind == BK.danger;
    return Pressable(
      onPress: off ? null : onPress,
      disabled: off,
      scale: 0.97,
      label: a11yLabel ?? label,
      hint: a11yHint,
      focusRadius: BorderRadius.circular(radius),
      builder: (context, pressed, focused) => Opacity(
        opacity: off ? 0.45 : 1,
        child: Container(
          constraints: BoxConstraints(minHeight: kind == BK.text ? 44 : (compact ? 36 : 48)),
          padding: EdgeInsets.symmetric(horizontal: kind == BK.text ? 4 : (compact ? 12 : 18)),
          decoration: BoxDecoration(
            color: kind == BK.primary ? null : bg,
            gradient: kind == BK.primary ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: brandGradient) : null,
            borderRadius: BorderRadius.circular(radius),
            border: bordered ? Border.all(color: kind == BK.danger ? const Color(0xFFE6B3B3) : GlassTokens.border) : null,
            boxShadow: kind == BK.primary
                ? const [BoxShadow(color: Color.fromRGBO(12, 79, 64, 0.28), blurRadius: 14, offset: Offset(0, 6))]
                : bordered
                    ? const [BoxShadow(color: Color.fromRGBO(12, 79, 64, 0.06), blurRadius: 24, offset: Offset(0, 10))]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: gapped([
              if (loading)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icon != null)
                FIcon(icon!, size: 15, color: fg),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: compact ? 12 : 14, color: fg)),
              ),
              if (iconRight != null && !loading) FIcon(iconRight!, size: 15, color: fg),
            ], 8),
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  final IconName name;
  final VoidCallback? onPress;
  final String label;
  final Color color;
  final String? badge;
  final bool filled;
  const IconBtn(this.name, {super.key, this.onPress, required this.label, this.color = AppColors.ink, this.badge, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPress: onPress,
      scale: 0.9,
      label: label,
      focusRadius: BorderRadius.circular(20),
      builder: (context, pressed, _) => SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pressed ? GlassTokens.pressed : (filled ? GlassTokens.fillStrong : null),
                border: filled ? Border.all(color: GlassTokens.border) : null,
              ),
              child: FIcon(name, size: 19, color: color),
            ),
            if (badge != null)
              Positioned(
                right: -3,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.badge,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: Fonts.bodyBold, height: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Pills, chips, tabs ----------

class Pill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconName? icon;
  final VoidCallback? onPress;
  final String? a11yLabel;
  const Pill(this.label, {super.key, this.tone = PillTone.neutral, this.icon, this.onPress, this.a11yLabel});

  @override
  Widget build(BuildContext context) {
    final p = pills[tone]!;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[FIcon(icon!, size: 11, color: p.fg), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 11, color: p.fg))),
      ]),
    );
    if (onPress == null) return Start(body);
    return Start(Pressable(onPress: onPress, label: a11yLabel ?? label, builder: (_, _, _) => body));
  }
}

class Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPress;
  const Chip(this.label, {super.key, this.selected = false, this.onPress});

  @override
  Widget build(BuildContext context) {
    Widget body(bool _) => Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPale : GlassTokens.fill,
            border: Border.all(color: selected ? AppColors.brand : GlassTokens.border),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected) ...[const FIcon('check', size: 13, color: AppColors.brand), const SizedBox(width: 6)],
            Flexible(child: Text(label, style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: selected ? AppColors.brand : AppColors.ink))),
          ]),
        );
    // A chip without an action is a label, not a button: don't announce it as tappable.
    if (onPress == null) return Semantics(label: label, excludeSemantics: true, child: body(false));
    return Pressable(
      onPress: onPress,
      scale: 0.95,
      label: label,
      checked: selected,
      focusRadius: BorderRadius.circular(Radii.pill),
      builder: (_, pressed, _) => body(pressed),
    );
  }
}

/// Wrap of chips, like flexDirection: 'row', flexWrap: 'wrap', gap: 8.
class ChipWrap extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const ChipWrap(this.children, {super.key, this.gap = 8});
  @override
  Widget build(BuildContext context) => Wrap(spacing: gap, runSpacing: gap, children: children);
}

class TabSpec<K> {
  final K key;
  final String label;
  final int? count;
  const TabSpec(this.key, this.label, [this.count]);
}

class SegmentTabs<K> extends StatelessWidget {
  final List<TabSpec<K>> tabs;
  final K value;
  final ValueChanged<K> onChange;
  const SegmentTabs({super.key, required this.tabs, required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final on = t.key == value;
            return Pressable(
              onPress: () => onChange(t.key),
              selected: on,
              label: t.count != null && t.count! > 0 ? '${t.label}, ${t.count}' : t.label,
              builder: (_, _, _) => Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? AppColors.brand : Colors.transparent, width: 2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t.label, style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 13, color: on ? AppColors.brand : AppColors.inkSoft)),
                  if (t.count != null && t.count! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.brandPale, borderRadius: BorderRadius.circular(9)),
                      child: Text('${t.count}', style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, color: AppColors.brand)),
                    ),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class FilterPills<K> extends StatelessWidget {
  final List<TabSpec<K>> options;
  final K value;
  final ValueChanged<K> onChange;
  const FilterPills({super.key, required this.options, required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = o.key == value;
        return Pressable(
          onPress: () => onChange(o.key),
          selected: on,
          label: o.label,
          focusRadius: BorderRadius.circular(Radii.pill),
          builder: (_, _, _) => Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.ink : GlassTokens.fill,
              border: Border.all(color: on ? AppColors.ink : GlassTokens.border),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(o.label, style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 12, color: on ? Colors.white : AppColors.ink)),
          ),
        );
      }).toList(),
    );
  }
}

class PlanStatusPill extends StatelessWidget {
  final String status;
  const PlanStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      'DRAFT' => (tr('Draft'), PillTone.neutral),
      'ACTIVE' => (tr('Active'), PillTone.ok),
      'FULL' => (tr('Full'), PillTone.warn),
      'UPDATED' => (tr('Updated'), PillTone.blue),
      'CANCELLED' => (tr('Cancelled'), PillTone.bad),
      'COMPLETED' => (tr('Completed'), PillTone.neutral),
      _ => (status, PillTone.neutral),
    };
    return Pill(label, tone: tone);
  }
}

// ---------- Avatars ----------

AvatarTone toneFor(int id) => AvatarTone.values.byName(toneNameFor(id));

class Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final int id;
  final double size;
  final AvatarTone? tone;
  const Avatar({super.key, required this.name, this.photoUrl, this.id = 0, this.size = 40, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = avatarTones[tone ?? toneFor(id)]!;
    final fallback = Text(
      initials(name),
      style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: size * 0.3 < 10 ? 10 : size * 0.3, color: t.fg, height: 1),
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(shape: BoxShape.circle, color: t.bg),
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)
            : fallback,
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final UserSummary user;
  final double size;
  const UserAvatar(this.user, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Avatar(name: user.displayName, photoUrl: user.photoUrl, id: user.id, size: size);
}

// ---------- Layout ----------

/// Every screen sits on the aurora backdrop; content eases in once on arrival.
class Screen extends StatelessWidget {
  final List<Widget> children;
  final bool scroll;
  final bool padded;
  final Future<void> Function()? onRefresh;
  final bool top;
  final bool bottom;
  final Widget? footer;
  final ScrollController? controller;

  /// Solid colour instead of the aurora (rarely needed).
  final Color? bg;

  /// For non-scrolling screens: the body widget fills the space.
  final Widget? body;

  const Screen({
    super.key,
    this.children = const [],
    this.scroll = true,
    this.padded = true,
    this.onRefresh,
    this.top = true,
    this.bottom = false,
    this.footer,
    this.controller,
    this.bg,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.symmetric(horizontal: padded ? 16 : 0);
    Widget content;
    if (scroll) {
      Widget list = SingleChildScrollView(
        controller: controller,
        physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: pad.copyWith(bottom: 40),
        child: Appear(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
      );
      if (onRefresh != null) list = RefreshIndicator(color: AppColors.brand, onRefresh: onRefresh!, child: list);
      content = list;
    } else {
      content = Appear(child: Padding(padding: pad, child: body ?? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
    }
    return Scaffold(
      backgroundColor: bg ?? AppColors.paper,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        if (bg == null) const Backdrop(),
        SafeArea(
          top: top,
          bottom: bottom,
          child: Column(children: [Expanded(child: content), ?footer]),
        ),
      ]),
    );
  }
}

void goBack() => Nav.goBack();

/// Screen header: back button + kicker/title, optional right action.
class Header extends StatelessWidget {
  final String? title;
  final String? kicker;
  final Widget? right;
  final VoidCallback? onBack;
  final bool center;
  final bool large;

  /// For the first step of a flow with nowhere to go back to: no button, rather than one that does nothing.
  final bool hideBack;
  const Header({super.key, this.title, this.kicker, this.right, this.onBack, this.center = false, this.large = true, this.hideBack = false});

  @override
  Widget build(BuildContext context) {
    final big = large && !center;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        if (hideBack) const SizedBox(width: 8) else IconBtn('chevron-left', label: tr('Back'), onPress: onBack ?? goBack, filled: true),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kicker != null && kicker!.isNotEmpty) Txt(kicker, variant: TV.kicker, maxLines: 1),
                if (title != null)
                  Txt(
                    title,
                    variant: big ? TV.title : TV.bodyStrong,
                    style: big ? const TextStyle(fontSize: 22, height: 26 / 22) : const TextStyle(fontSize: 15),
                    maxLines: 1,
                    header: true,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 40), child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: right)),
      ]),
    );
  }
}

class Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPress;
  final String? a11yLabel;
  final EdgeInsetsGeometry padding;
  const Card({super.key, required this.child, this.onPress, this.a11yLabel, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
          padding: padding,
          decoration: BoxDecoration(
            color: GlassTokens.fill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: GlassTokens.border),
            boxShadow: glassShadow,
          ),
          child: child,
        );
    if (onPress == null) return box();
    return Pressable(onPress: onPress, scale: 0.985, label: a11yLabel, focusRadius: BorderRadius.circular(22), builder: (_, _, _) => box());
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final bool danger;
  const SectionTitle(this.title, {super.key, this.danger = false});
  @override
  Widget build(BuildContext context) =>
      Txt(title.toUpperCase(), variant: TV.section, style: danger ? const TextStyle(color: AppColors.danger) : null);
}

/// A bordered group of rows (settings, safety tools…).
class Group extends StatelessWidget {
  final List<Widget> children;
  final bool danger;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  const Group(this.children, {super.key, this.danger = false, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GlassTokens.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: danger ? const Color(0xFFEFC9C9) : GlassTokens.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class IconTile extends StatelessWidget {
  final IconName name;
  final PillTone tone;
  final double size;
  const IconTile(this.name, {super.key, this.tone = PillTone.ok, this.size = 38});
  @override
  Widget build(BuildContext context) {
    final p = pills[tone]!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(size * 0.32)),
      child: FIcon(name, size: size * 0.48, color: p.fg),
    );
  }
}

const _rowLabel = TextStyle(fontFamily: Fonts.bodyBold, fontSize: 14, color: AppColors.ink);
const _rowSub = TextStyle(fontFamily: Fonts.body, fontSize: 12, height: 17 / 12, color: AppColors.inkSoft);
const _rowValue = TextStyle(fontFamily: Fonts.bodySemi, fontSize: 12, color: AppColors.inkSoft);

/// Row inside a Group: icon tile, label/sub, value or toggle, chevron.
class ListRow extends StatelessWidget {
  final IconName? icon;
  final String label;
  final String? sub;
  final String? value;
  final VoidCallback? onPress;
  final bool first;
  final bool danger;
  final String? tag;
  final PillTone tagTone;
  final Widget? right;
  final String? a11yLabel;
  const ListRow({
    super.key,
    this.icon,
    required this.label,
    this.sub,
    this.value,
    this.onPress,
    this.first = false,
    this.danger = false,
    this.tag,
    this.tagTone = PillTone.warn,
    this.right,
    this.a11yLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget content(bool pressed) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: pressed ? GlassTokens.pressed : null,
            border: first ? null : const Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            if (icon != null) ...[IconTile(icon!, tone: danger ? PillTone.bad : PillTone.ok), const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
                  Text(label, style: danger ? _rowLabel.copyWith(color: AppColors.danger) : _rowLabel),
                  if (tag != null) Pill(tag!, tone: tagTone),
                ]),
                if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 2), Text(sub!, style: _rowSub)],
              ]),
            ),
            const SizedBox(width: 12),
            right ??
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (value != null && value!.isNotEmpty)
                      Flexible(child: Text(value!, style: _rowValue, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (onPress != null) ...[const SizedBox(width: 4), const FIcon('chevron-right', size: 16, color: AppColors.inkSoft)],
                  ]),
                ),
          ]),
        );
    final a11y = a11yLabel ?? [label, sub, value, tag].where((s) => s != null && s.isNotEmpty).join(', ');
    if (onPress == null) {
      if (right != null) return content(false); // keep the switch inside reachable
      return Semantics(label: a11y, excludeSemantics: true, child: content(false));
    }
    return Pressable(onPress: onPress, label: a11y, focusRadius: BorderRadius.zero, builder: (_, pressed, _) => content(pressed));
  }
}

class Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChange;
  final String label;
  final bool disabled;
  const Switch({super.key, required this.value, required this.onChange, required this.label, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final still = reducedMotion(context);
    final d = still ? Duration.zero : const Duration(milliseconds: 260);
    return Pressable(
      onPress: disabled ? null : () => onChange(!value),
      disabled: disabled,
      toggled: value,
      label: label,
      focusRadius: BorderRadius.circular(13),
      builder: (_, _, _) => Opacity(
        opacity: disabled ? 0.45 : 1,
        child: AnimatedContainer(
          duration: d,
          curve: Curves.easeOutBack,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: value ? AppColors.brand : AppColors.track, borderRadius: BorderRadius.circular(13)),
          child: AnimatedAlign(
            duration: d,
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: value ? const FIcon('check', size: 12, color: AppColors.brand) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  final IconName? icon;
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChange;
  final bool first;
  final String? tag;
  final bool disabled;
  const ToggleRow({
    super.key,
    this.icon,
    required this.label,
    this.sub,
    required this.value,
    required this.onChange,
    this.first = false,
    this.tag,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => ListRow(
        icon: icon,
        label: label,
        sub: sub,
        first: first,
        tag: tag,
        right: Switch(value: value, onChange: onChange, label: label, disabled: disabled),
      );
}

class RadioOption<V> {
  final V value;
  final String label;
  final String? sub;
  final bool disabled;
  const RadioOption(this.value, this.label, {this.sub, this.disabled = false});
}

/// Radio card list (choice screens, report reasons, wizard options).
class RadioCards<V> extends StatelessWidget {
  final List<RadioOption<V>> options;
  final V? value;
  final ValueChanged<V> onChange;
  final String label;
  const RadioCards({super.key, required this.options, required this.value, required this.onChange, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: Col(
        gap: 8,
        options.map((o) {
          final on = o.value == value;
          return Pressable(
            onPress: o.disabled ? null : () => onChange(o.value),
            disabled: o.disabled,
            checked: on,
            inMutuallyExclusiveGroup: true,
            label: o.sub != null ? '${o.label}, ${o.sub}' : o.label,
            focusRadius: BorderRadius.circular(18),
            builder: (_, _, _) => Opacity(
              opacity: o.disabled ? 0.5 : 1,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: on ? AppColors.brandPale : GlassTokens.fill,
                  border: Border.all(color: on ? AppColors.brand : GlassTokens.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? AppColors.brand : AppColors.inputBorder, width: 2)),
                    child: on ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.label, style: _rowLabel),
                      if (o.sub != null) Text(o.sub!, style: _rowSub),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StepBars extends StatelessWidget {
  final int total;
  final int current;
  const StepBars({super.key, required this.total, required this.current});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Step {current} of {total}', {'current': current, 'total': total}),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: gapped(
            List.generate(
              total,
              (i) => Expanded(
                child: Container(height: 4, decoration: BoxDecoration(color: i < current ? AppColors.brand : AppColors.line, borderRadius: BorderRadius.circular(2))),
              ),
            ),
            6,
          ),
        ),
      ),
    );
  }
}

class KV {
  final String k;
  final String v;
  const KV(this.k, this.v);
}

class KeyValue extends StatelessWidget {
  final List<KV> rows;
  const KeyValue(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    return Group([
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rows[i].k, style: _rowSub),
            const SizedBox(width: 12),
            Expanded(child: Text(rows[i].v, style: _rowLabel, textAlign: TextAlign.right)),
          ]),
        ),
    ]);
  }
}

class Diff extends StatelessWidget {
  final List<FieldChange> changes;
  const Diff(this.changes, {super.key});
  @override
  Widget build(BuildContext context) {
    return Col(
      gap: 6,
      changes
          .map((d) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: GlassTokens.fillSoft, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(d.label).toUpperCase(),
                      style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 10, letterSpacing: 1, color: AppColors.inkSoft)),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(style: _rowSub, children: [
                      TextSpan(text: d.from, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                      const TextSpan(text: '  →  '),
                      TextSpan(text: d.to, style: const TextStyle(fontFamily: Fonts.bodyBold, color: AppColors.ink)),
                    ]),
                  ),
                ]),
              ))
          .toList(),
    );
  }
}

class Banner extends StatelessWidget {
  final IconName icon;
  final String title;
  final String? body;
  final PillTone tone;
  final String? action;
  final VoidCallback? onAction;
  const Banner({super.key, required this.icon, required this.title, this.body, this.tone = PillTone.ok, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = pills[tone]!;
    final warn = tone == PillTone.warn;
    return Semantics(
      liveRegion: tone == PillTone.bad || warn,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: warn ? const Color(0xFFFFF8E6) : p.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: warn ? const Color(0xFFF0DCA6) : Colors.transparent),
        ),
        child: Row(children: [
          FIcon(icon, size: 17, color: p.fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: Fonts.bodyBold, color: tone == PillTone.ok ? AppColors.ink : p.fg, fontSize: 13)),
              if (body != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(body!, style: const TextStyle(fontFamily: Fonts.body, color: AppColors.inkSoft, fontSize: 12, height: 17 / 12)),
                ),
            ]),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            Pressable(
              onPress: onAction,
              label: action,
              builder: (_, _, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(action!, style: TextStyle(fontFamily: Fonts.bodyBold, color: p.fg, fontSize: 12)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class Note extends StatelessWidget {
  final IconName icon;
  final String? text;
  final List<InlineSpan>? spans;
  const Note(this.text, {super.key, this.icon = 'lock'}) : spans = null;
  const Note.rich(this.spans, {super.key, this.icon = 'lock'}) : text = null;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: Fonts.body, fontSize: 12, height: 17 / 12, color: AppColors.inkSoft);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: GlassTokens.fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: GlassTokens.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FIcon(icon, size: 14, color: AppColors.brand),
        const SizedBox(width: 8),
        Expanded(child: spans != null ? Text.rich(TextSpan(children: spans), style: style) : Text(text ?? '', style: style)),
      ]),
    );
  }
}

class EmergencyNote extends StatelessWidget {
  const EmergencyNote({super.key});
  @override
  Widget build(BuildContext context) => Note.rich(icon: 'shield', [
        bold(tr('If you are in immediate danger,')),
        TextSpan(text: ' ${tr('contact your local emergency services (112 in India) or someone you trust. Plans isn’t an emergency service.')}'),
      ]);
}

// ---------- States ----------

class Loading extends StatelessWidget {
  final String? label;
  const Loading({super.key, this.label});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.brand)),
            if (label != null) Padding(padding: const EdgeInsets.only(top: 10), child: Txt(label, variant: TV.small)),
          ]),
        ),
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  final int rows;
  const Skeleton({super.key, this.rows = 3});
  @override
  Widget build(BuildContext context) {
    Widget block(double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(height: 10, decoration: BoxDecoration(color: const Color.fromRGBO(24, 35, 33, 0.08), borderRadius: BorderRadius.circular(5))),
        );
    return Semantics(
      label: tr('Loading'),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Col(
          gap: 10,
          List.generate(
            rows,
            (_) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GlassTokens.fillSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GlassTokens.border),
              ),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color.fromRGBO(24, 35, 33, 0.08), borderRadius: BorderRadius.circular(12))),
                const SizedBox(width: 12),
                Expanded(child: Col(gap: 7, [block(0.55), block(0.85)])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class StateAction {
  final String label;
  final VoidCallback onPress;
  final BK kind;
  const StateAction(this.label, this.onPress, [this.kind = BK.primary]);
}

class StateBlock extends StatelessWidget {
  final IconName icon;
  final String title;
  final String? body;
  final PillTone tone;
  final List<StateAction> actions;
  const StateBlock({super.key, required this.icon, required this.title, this.body, this.tone = PillTone.ok, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
      child: Column(children: [
        IconTile(icon, tone: tone, size: 56),
        const SizedBox(height: 14),
        Txt(title, variant: TV.title, align: TextAlign.center, style: const TextStyle(fontSize: 22), header: true),
        if (body != null) Padding(padding: const EdgeInsets.only(top: 8), child: Txt(body, align: TextAlign.center)),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Col(gap: 8, actions.map((a) => Button(a.label, kind: a.kind, onPress: a.onPress)).toList()),
          ),
      ]),
    );
  }
}

class ErrorBlock extends StatelessWidget {
  final String message;
  final bool isNetwork;
  final VoidCallback onRetry;
  final String? title;
  const ErrorBlock({super.key, required this.message, this.isNetwork = false, required this.onRetry, this.title});
  ErrorBlock.of(Object error, {super.key, required this.onRetry, this.title})
      : message = error is ApiError ? error.message : error.toString(),
        isNetwork = error is ApiError && error.isNetwork;

  @override
  Widget build(BuildContext context) {
    return StateBlock(
      icon: isNetwork ? 'wifi-off' : 'refresh-cw',
      tone: PillTone.neutral,
      title: isNetwork ? tr('You’re offline') : (title ?? tr('Couldn’t load this')),
      body: isNetwork ? tr('Reconnect and try again.') : message,
      actions: [StateAction(tr('Retry'), onRetry)],
    );
  }
}

// ---------- Forms ----------

/// Labelled text input. Controlled like a React input: `value` in, `onChanged` out.
class Field extends StatefulWidget {
  final String label;
  final bool optional;
  final String? hint;
  final String? error;
  final String? prefix;
  final String value;
  final ValueChanged<String>? onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final Iterable<String>? autofill;
  final bool obscure;
  final bool multiline;
  final int? maxLength;
  final bool autofocus;
  final bool autocorrect;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? formatters;

  const Field({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.optional = false,
    this.hint,
    this.error,
    this.prefix,
    this.placeholder,
    this.keyboardType,
    this.capitalization = TextCapitalization.sentences,
    this.autofill,
    this.obscure = false,
    this.multiline = false,
    this.maxLength,
    this.autofocus = false,
    this.autocorrect = true,
    this.action,
    this.onSubmitted,
    this.focusNode,
    this.formatters,
  });

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant Field old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      _c.value = TextEditingValue(text: widget.value, selection: TextSelection.collapsed(offset: widget.value.length));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = widget.error != null && widget.error!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: widget.label),
              if (widget.optional)
                TextSpan(text: ' ${tr('(optional)')}', style: const TextStyle(fontFamily: Fonts.body, color: AppColors.inkSoft)),
            ]),
            style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 13, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: BoxConstraints(minHeight: widget.multiline ? 96 : 50),
          padding: EdgeInsets.only(left: 14, right: 14, top: widget.multiline ? 12 : 0),
          decoration: BoxDecoration(
            color: GlassTokens.fillStrong,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: err ? AppColors.danger : AppColors.inputBorder),
          ),
          child: Row(
            crossAxisAlignment: widget.multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.prefix != null) ...[
                Text(widget.prefix!, style: const TextStyle(fontFamily: Fonts.bodyBold, fontSize: 15, color: AppColors.ink)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Semantics(
                  label: widget.label,
                  child: TextField(
                    controller: _c,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    autofocus: widget.autofocus,
                    autocorrect: widget.autocorrect,
                    keyboardType: widget.multiline ? TextInputType.multiline : widget.keyboardType,
                    textCapitalization: widget.capitalization,
                    autofillHints: widget.autofill,
                    obscureText: widget.obscure,
                    enableSuggestions: !widget.obscure,
                    minLines: widget.multiline ? 3 : 1,
                    maxLines: widget.multiline ? null : 1,
                    textInputAction: widget.action ?? (widget.multiline ? TextInputAction.newline : null),
                    inputFormatters: [
                      if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
                      ...?widget.formatters,
                    ],
                    style: const TextStyle(fontFamily: Fonts.body, fontSize: 15, color: AppColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: widget.multiline ? 0 : 14),
                      hintText: widget.placeholder,
                      hintStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 15, color: placeholderColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (err)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Semantics(
              liveRegion: true,
              child: Text(widget.error!, style: const TextStyle(fontFamily: Fonts.bodySemi, fontSize: 12, color: AppColors.dangerText)),
            ),
          )
        else if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(widget.hint!, style: const TextStyle(fontFamily: Fonts.body, fontSize: 11, color: AppColors.inkSoft)),
          ),
      ]),
    );
  }
}

final digitsOnly = FilteringTextInputFormatter.digitsOnly;

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 20});
  @override
  Widget build(BuildContext context) {
    Widget bar(double h) => Container(width: 3, height: h, decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(3)));
    return Semantics(
      label: tr('Plans'),
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Transform.rotate(
          angle: -4 * 3.1415926535 / 180,
          child: Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(9)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: gapped([bar(7), bar(13), bar(9)], 2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(tr('Plans'), style: TextStyle(fontFamily: Fonts.display, fontSize: size, color: AppColors.ink)),
      ]),
    );
  }
}

class ScrollRow extends StatelessWidget {
  final List<Widget> children;
  const ScrollRow(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: gapped(children, 8)),
    );
  }
}
