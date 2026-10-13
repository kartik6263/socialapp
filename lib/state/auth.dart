import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/client.dart' as client;

const _key = 'plans.tokens';

/// Tokens live in the Keychain / Keystore via flutter_secure_storage.
class AuthState extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  bool ready = false;
  Me? _user;
  Me? get user => _user;
  set user(Me? u) {
    _user = u;
    if (u != null) lastUser = u;
  }

  /// Kept while signing out, so screens that are still closing can draw one last frame.
  Me? lastUser;
  bool sessionExpired = false;
  client.Tokens? _tokens;

  /// Server-controlled switches for modules kept out of v1. Loaded after sign-in; all off until then.
  Features features = Features.allOff;

  Future<void> _loadConfig() async {
    try {
      features = (await ConfigApi.get()).features;
    } catch (_) {
      features = Features.allOff;
    }
    notifyListeners();
  }

  Future<void> _persist(client.Tokens? t) async {
    client.setTokens(t);
    _tokens = t;
    try {
      if (t != null) {
        await _storage.write(key: _key, value: jsonEncode(t.toJson()));
      } else {
        await _storage.delete(key: _key);
      }
    } catch (_) {}
  }

  Future<void> init() async {
    client.configureAuth(
      onTokensChanged: (t) => _persist(t),
      onSessionExpired: () {
        sessionExpired = true;
        user = null;
        notifyListeners();
      },
    );
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (_) {}
    if (raw != null) {
      try {
        final t = client.Tokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        client.setTokens(t);
        _tokens = t;
        user = await MeApi.get();
        unawaited(_loadConfig());
      } catch (_) {
        // Expired/invalid tokens or server unreachable: start signed out instead of blocking on splash.
        await _persist(null);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> signIn(AuthResponse res) async {
    await _persist(client.Tokens(res.accessToken, res.refreshToken));
    sessionExpired = false;
    user = res.user;
    notifyListeners();
    unawaited(_loadConfig());
  }

  Future<void> signOut() async {
    final t = _tokens;
    if (t != null) {
      try {
        await AuthApi.logout(t.refreshToken);
      } catch (_) {}
    }
    await _persist(null);
    user = null;
    features = Features.allOff;
    notifyListeners();
  }

  void setUser(Me u) {
    user = u;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = await MeApi.get();
    notifyListeners();
  }
}

/// The signed-in user. Only call from screens behind the signed-in guard.
Me useMe(BuildContext context) {
  final s = context.watch<AuthState>();
  final u = s.user ?? s.lastUser;
  if (u == null) throw StateError('useMe called while signed out');
  return u;
}

AuthState authOf(BuildContext context) => context.read<AuthState>();
