import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../i18n/i18n.dart';

// --dart-define=API_URL=... wins; otherwise 10.0.2.2 = the host machine from the Android emulator
// (the same default the Expo app had in app.json "extra.apiUrl").
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

class ApiError implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, String>? fields;
  final int? existingId;
  ApiError(this.status, this.code, this.message, {this.fields, this.existingId});

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// Wraps anything thrown into an ApiError, the way screens expect it.
ApiError asApiError(Object e) => e is ApiError ? e : ApiError(0, 'UNKNOWN', e.toString());

class Tokens {
  final String accessToken;
  final String refreshToken;
  const Tokens(this.accessToken, this.refreshToken);
  Map<String, String> toJson() => {'accessToken': accessToken, 'refreshToken': refreshToken};
  static Tokens fromJson(Map<String, dynamic> j) => Tokens(j['accessToken'] as String, j['refreshToken'] as String);
}

http.Client _http = http.Client();

/// Tests swap in a fake backend (package:http/testing.dart MockClient).
void setHttpClient(http.Client client) => _http = client;

Tokens? _tokens;
void Function(Tokens?)? _onTokensChanged;
void Function()? _onSessionExpired;
Future<bool>? _refreshing;

void configureAuth({required void Function(Tokens?) onTokensChanged, required void Function() onSessionExpired}) {
  _onTokensChanged = onTokensChanged;
  _onSessionExpired = onSessionExpired;
}

void setTokens(Tokens? t) => _tokens = t;
String? getAccessToken() => _tokens?.accessToken;

String _platform = 'ANDROID';
String appVersionString = '1.0.0';
Map<String, String> _deviceHeaders = {};

/// Reads the device model and app version once at startup.
Future<void> initDeviceHeaders() async {
  _platform = Platform.isIOS ? 'IOS' : 'ANDROID';
  var model = Platform.operatingSystem;
  try {
    final info = DeviceInfoPlugin();
    // Model only ("Pixel 7"), not the user-set device name — that often contains the owner's real name.
    if (Platform.isAndroid) {
      model = (await info.androidInfo).model;
    } else if (Platform.isIOS) {
      model = (await info.iosInfo).utsname.machine;
    }
  } catch (_) {}
  try {
    appVersionString = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  _deviceHeaders = {'X-Client-Platform': _platform, 'X-Client-Device': model, 'X-Client-Version': appVersionString};
}

String get clientPlatform => _platform;

/// Single-flight refresh: concurrent 401s wait on the same rotation.
Future<bool> _refresh() {
  final rt = _tokens?.refreshToken;
  if (rt == null) return Future.value(false);
  return _refreshing ??= () async {
    try {
      final res = await _http.post(
        Uri.parse('$apiUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json', ..._deviceHeaders},
        body: jsonEncode({'refreshToken': rt}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final next = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      _tokens = Tokens(next['accessToken'] as String, next['refreshToken'] as String);
      _onTokensChanged?.call(_tokens);
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = null;
    }
  }();
}

Future<dynamic> _request(String method, String path, {Object? body, bool hasBody = false, bool retried = false}) async {
  final headers = <String, String>{'Accept': 'application/json', ..._deviceHeaders};
  if (hasBody) headers['Content-Type'] = 'application/json';
  if (_tokens != null) headers['Authorization'] = 'Bearer ${_tokens!.accessToken}';

  final req = http.Request(method, Uri.parse('$apiUrl$path'))..headers.addAll(headers);
  if (hasBody) req.body = jsonEncode(body);

  http.Response res;
  try {
    res = await http.Response.fromStream(await _http.send(req));
  } catch (_) {
    throw ApiError(0, 'NETWORK', tr('You’re offline. Reconnect and try again.'));
  }

  if (res.statusCode == 401 && _tokens != null && !retried) {
    if (await _refresh()) return _request(method, path, body: body, hasBody: hasBody, retried: true);
    _tokens = null;
    _onTokensChanged?.call(null);
    _onSessionExpired?.call();
  }

  if (res.statusCode < 200 || res.statusCode >= 300) {
    Map<String, dynamic> err = {};
    try {
      err = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      // non-JSON error body
    }
    final fields = (err['fields'] as Map?)?.map((k, v) => MapEntry(k.toString(), translateServer(v?.toString())));
    // Server messages are English; show them in the user's language when a translation exists.
    throw ApiError(
      res.statusCode,
      (err['code'] as String?) ?? 'ERROR',
      translateServer((err['message'] as String?) ?? 'Something went wrong. Try again.'),
      fields: fields,
      existingId: (err['existingId'] as num?)?.toInt(),
    );
  }

  if (res.statusCode == 204) return null;
  final text = utf8.decode(res.bodyBytes);
  return text.isEmpty ? null : jsonDecode(text);
}

class Http {
  static Future<dynamic> get(String path) => _request('GET', path);
  static Future<dynamic> post(String path, [Object? body]) => _request('POST', path, body: body ?? const {}, hasBody: true);
  static Future<dynamic> put(String path, [Object? body]) => _request('PUT', path, body: body ?? const {}, hasBody: true);
  static Future<dynamic> del(String path) => _request('DELETE', path);
}

String query(Map<String, Object?> params) {
  final parts = params.entries
      .where((e) => e.value != null && e.value != '')
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}');
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}
