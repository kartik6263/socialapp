import 'dart:async';

import 'package:flutter/semantics.dart';
import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../theme.dart';

class ToastController extends ChangeNotifier {
  String message = '';
  bool visible = false;
  Timer? _timer;

  /// Set by the overlay so announcements go to the right view.
  FlutterView? view;

  void show(String text) {
    message = text;
    // Read out once, like accessibilityLiveRegion="polite".
    final v = view;
    if (v != null) SemanticsService.sendAnnouncement(v, text, TextDirection.ltr);
    visible = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      visible = false;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// `toast(context)('Saved')`, like the React app's useToast().
void Function(String) useToast(BuildContext context) => context.read<ToastController>().show;

class ToastOverlay extends StatelessWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ToastController>();
    t.view = View.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: t.visible ? 1 : 0,
          duration: Duration(milliseconds: t.visible ? 160 : 200),
          child: AnimatedSlide(
            offset: t.visible ? Offset.zero : const Offset(0, 0.25),
            duration: Duration(milliseconds: t.visible ? 160 : 200),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(24, 35, 33, 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.14)),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 8))],
              ),
              child: Text(
                t.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontFamily: Fonts.bodySemi, fontSize: 13, decoration: TextDecoration.none),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
