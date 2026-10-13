import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme.dart';

/// The light behind every screen. Three soft radial glows on a pale base — static, so it costs nothing per frame.
/// Purely decorative: hidden from screen readers.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: Aurora.base),
              ),
              child: CustomPaint(painter: _GlowPainter(), size: Size.infinite),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  // Same rectangles as the SVG version: x, y, width, height as fractions of the screen.
  static const _glows = [
    (-0.35, -0.20, 1.10, 0.60, Aurora.mint),
    (0.45, -0.10, 0.80, 0.40, Aurora.lime),
    (0.10, 0.55, 1.10, 0.60, Aurora.violet),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, w, h, color) in _glows) {
      final rect = Rect.fromLTWH(x * size.width, y * size.height, w * size.width, h * size.height);
      // An SVG radialGradient with r=50% on a non-square box is an ellipse; scale a unit circle to match.
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.scale(rect.width / 2, rect.height / 2);
      final paint = Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
      canvas.drawRect(const Rect.fromLTRB(-1, -1, 1, 1), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A frosted surface. Real blur only where it earns its cost (floating bars, sheets — pass `blur`), and only on iOS:
/// Android gets a slightly more opaque fill that reads the same.
class Glass extends StatelessWidget {
  final Widget? child;
  final bool blur;
  final bool strong;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  const Glass({super.key, this.child, this.blur = false, this.strong = false, this.radius = 20, this.padding, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final realBlur = blur && Platform.isIOS;
    final br = BorderRadius.circular(radius);
    final fill = realBlur ? const Color.fromRGBO(255, 255, 255, 0.45) : (strong ? GlassTokens.fillStrong : GlassTokens.fill);
    Widget inner = Stack(
      children: [
        if (realBlur)
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: const SizedBox())),
        Positioned.fill(child: ColoredBox(color: fill)),
        // Light catching the top edge of the glass.
        const Positioned(top: 0, left: 0, right: 0, height: 1, child: ColoredBox(color: GlassTokens.highlight)),
        Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ],
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: br, border: Border.all(color: GlassTokens.border), boxShadow: glassShadow),
      child: ClipRRect(borderRadius: br, child: inner),
    );
  }
}

/// Shadows show through translucent fills as a grey rim on Android, so glass there relies on its border (as before).
List<BoxShadow>? get glassShadow => Platform.isIOS ? GlassTokens.shadow : null;
