import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// App-wide navigation, mirroring expo-router's `router` object so helpers outside widgets can navigate.
/// Tab roots (/, /plans, /chats, /me) are switched with `go`; everything else is pushed over the tabs.
class Nav {
  static late GoRouter router;
  static final rootKey = GlobalKey<NavigatorState>();

  static const tabRoots = {'/', '/plans', '/chats', '/me'};

  static String _withQuery(String path, Map<String, String>? params) {
    if (params == null || params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  /// router.push: opens a screen on top. Tab roots switch tabs instead (as expo-router does for tab routes).
  static void push(String path, [Map<String, String>? params]) {
    if (tabRoots.contains(path)) {
      router.go(path);
      return;
    }
    router.push(_withQuery(path, params));
  }

  /// router.navigate('/'): back to a tab, closing anything on top.
  static void navigate(String path) => router.go(path);

  /// router.replace: swaps the current screen.
  static void replace(String path, [Map<String, String>? params]) {
    if (tabRoots.contains(path)) {
      router.go(path);
      return;
    }
    if (router.canPop()) {
      router.pushReplacement(_withQuery(path, params));
    } else {
      router.go(_withQuery(path, params));
    }
  }

  static bool canGoBack() => router.canPop();

  static void back() {
    if (router.canPop()) router.pop();
  }

  /// goBack(): back if possible, otherwise home.
  static void goBack() {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }

  /// router.dismissTo: pops back to an earlier screen in the stack, or opens it if it isn't there.
  static void dismissTo(String path) {
    final nav = rootKey.currentState;
    var found = false;
    nav?.popUntil((route) {
      if (route.settings.name == path) found = true;
      return found || route.isFirst;
    });
    if (!found) push(path);
  }
}
