import 'package:flutter/widgets.dart';

import '../theme.dart';
import 'feather_glyphs.dart';

/// Feather icon names, exactly as used by @expo/vector-icons ("chevron-left", "map-pin"…).
typedef IconName = String;

IconData featherIcon(IconName name) => featherGlyphs[name] ?? featherGlyphs['help-circle']!;

class FIcon extends StatelessWidget {
  final IconName name;
  final double size;
  final Color color;
  const FIcon(this.name, {super.key, this.size = 20, this.color = AppColors.ink});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: Icon(featherIcon(name), size: size, color: color));
}
