import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Motion is used for three jobs only: confirming a touch (press), orienting on arrival (appear), and showing a
/// state change (switches, tabs, sheets). Everything turns off when the person has "Reduce motion" on.
bool reducedMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades content in and lifts it 10px — once, on mount. `delay` staggers siblings.
class Appear extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const Appear({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reducedMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// A press target that dips to `scale` while pressed, shows a focus ring for keyboard / switch access,
/// and reports itself to screen readers. The shared building block for buttons, chips, cards and rows.
class Pressable extends StatefulWidget {
  final Widget Function(BuildContext context, bool pressed, bool focused) builder;
  final VoidCallback? onPress;
  final double scale;
  final String? label;
  final String? hint;
  final bool button;
  final bool? checked;
  final bool? selected;
  final bool? toggled;
  final bool inMutuallyExclusiveGroup;
  final bool link;
  final bool header;
  final bool disabled;
  final BorderRadius focusRadius;

  const Pressable({
    super.key,
    required this.builder,
    this.onPress,
    this.scale = 1,
    this.label,
    this.hint,
    this.button = true,
    this.checked,
    this.selected,
    this.toggled,
    this.inMutuallyExclusiveGroup = false,
    this.link = false,
    this.header = false,
    this.disabled = false,
    this.focusRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPress != null && !widget.disabled;
    final still = reducedMotion(context);
    final scale = (_pressed && !still) ? widget.scale : 1.0;
    Widget content = AnimatedScale(
      scale: scale,
      duration: _pressed ? const Duration(milliseconds: 90) : const Duration(milliseconds: 180),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: widget.builder(context, _pressed, _focused),
    );
    if (_focused) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(borderRadius: widget.focusRadius, border: Border.all(color: focusRingColor, width: 2)),
        child: content,
      );
    }
    final gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled ? widget.onPress : null,
      child: content,
    );
    return Semantics(
      container: true,
      button: widget.button && !widget.link && widget.checked == null && widget.toggled == null,
      link: widget.link,
      header: widget.header,
      enabled: widget.onPress == null ? null : enabled,
      checked: widget.checked,
      selected: widget.selected,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.label,
      hint: widget.hint,
      excludeSemantics: widget.label != null,
      onTap: enabled ? widget.onPress : null,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onPress?.call();
            return null;
          }),
        },
        child: gesture,
      ),
    );
  }
}

/// Visible focus for keyboard and switch-access users.
const focusRingColor = Color(0xFF0B5CAD);
