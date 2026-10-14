import 'package:flutter/widgets.dart';

import '../api/client.dart';

/// Notified when screens above another screen are closed, so the one underneath can refresh.
final routeObserver = RouteObserver<ModalRoute<void>>();

/// Tab screens live in their own navigators; the tab shell bumps this when a tab is shown again.
class TabFocus extends InheritedWidget {
  final ValueNotifier<int> tick;
  const TabFocus({super.key, required this.tick, required super.child});

  static ValueNotifier<int>? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabFocus>()?.tick;

  @override
  bool updateShouldNotify(TabFocus oldWidget) => tick != oldWidget.tick;
}

/// Loads data when the screen gains focus and exposes loading / error / refresh state.
/// Keeps the last good data while refreshing so screens don't flash empty.
/// (The React app's useFocusData.)
mixin FocusData<W extends StatefulWidget, T> on State<W> implements RouteAware {
  T? data;
  ApiError? error;
  bool _loadingFlag = true;
  bool refreshing = false;
  ModalRoute<void>? _route;
  ValueNotifier<int>? _tab;

  Future<T> load();

  bool get loading => _loadingFlag && data == null;

  void setData(T? value) => setState(() => data = value);

  Future<void> _run(bool refresh) async {
    if (refresh && mounted) setState(() => refreshing = true);
    try {
      final result = await load();
      if (!mounted) return;
      setState(() {
        data = result;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = asApiError(e));
    } finally {
      if (mounted) {
        setState(() {
          _loadingFlag = false;
          refreshing = false;
        });
      }
    }
  }

  /// Pull-to-refresh and retry buttons.
  Future<void> refresh() => _run(true);

  /// Reload without the refresh spinner (focus, or a changed filter).
  Future<void> reload() => _run(false);

  void _onTab() => reload();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) routeObserver.subscribe(this, route);
    }
    final tab = TabFocus.maybeOf(context);
    if (tab != _tab) {
      _tab?.removeListener(_onTab);
      _tab = tab;
      _tab?.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tab?.removeListener(_onTab);
    super.dispose();
  }

  @override
  void didPopNext() => reload();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
