import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/api.dart';
import '../i18n/i18n.dart';
import 'misc.dart';

/// 'granted' | 'denied' | 'undetermined'
typedef PushPermission = String;

final _local = FlutterLocalNotificationsPlugin();
bool _firebaseReady = false;
bool _initialized = false;

const _defaultChannel = AndroidNotificationChannel('default', 'Plans', importance: Importance.defaultImportance);

/// Opens the screen a push points to, using the same deep-link map as the in-app list.
void _openFromData(Map<String, dynamic>? data) {
  final kind = data?['kind'] as String?;
  if (kind == null || kind.isEmpty) return;
  final id = data?['id']?.toString();
  final mode = data?['mode']?.toString();
  openDestination(Destination(kind, id: id != null && id.isNotEmpty ? int.tryParse(id) : null, mode: mode != null && mode.isNotEmpty ? mode : null));
}

/// Sets up delivery and tap handling once the signed-in app opens.
/// Firebase needs google-services.json / GoogleService-Info.plist; without them push stays off and the app works normally.
Future<void> initPush() async {
  if (_initialized) return;
  _initialized = true;
  try {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) _openFromData(jsonDecode(r.payload!) as Map<String, dynamic>);
      },
    );
  } catch (_) {}
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (_) {
    _firebaseReady = false;
  }
  if (!_firebaseReady) return;
  // Foreground pushes show as a banner, without sound or badge (as before).
  FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    if (n == null) return;
    _local.show(
      id: m.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          n.android?.channelId ?? _defaultChannel.id,
          n.android?.channelId == 'important' ? tr('Important Plan updates') : 'Plans',
          playSound: false,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: false, presentBadge: false),
      ),
      payload: jsonEncode(m.data),
    );
  });
  FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) _openFromData(initial.data);
}

Future<PushPermission> getPushPermission() async {
  try {
    final s = await Permission.notification.status;
    if (s.isGranted || s.isLimited || s.isProvisional) return 'granted';
    if (s.isPermanentlyDenied || s.isRestricted) return 'denied';
    return 'undetermined';
  } catch (_) {
    return 'undetermined';
  }
}

Future<bool> _isDevice() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) return (await info.androidInfo).isPhysicalDevice;
    if (Platform.isIOS) return (await info.iosInfo).isPhysicalDevice;
  } catch (_) {}
  return false;
}

/// Asks for OS permission and registers the native FCM/APNs token with our backend.
/// We send through FCM/APNs directly (not a third-party relay) so delivery scales with Google/Apple infra.
Future<PushPermission> enablePush() async {
  if (!await _isDevice()) return 'denied';
  if (Platform.isAndroid) {
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.createNotificationChannel(_defaultChannel);
      await android?.createNotificationChannel(AndroidNotificationChannel('important', tr('Important Plan updates'), importance: Importance.high));
    } catch (_) {}
  }
  final status = await Permission.notification.request();
  if (!(status.isGranted || status.isLimited || status.isProvisional)) {
    return 'denied'; // the person said no to the prompt
  }
  try {
    if (_firebaseReady) {
      final token = Platform.isIOS ? await FirebaseMessaging.instance.getAPNSToken() : await FirebaseMessaging.instance.getToken();
      if (token != null) await MeApi.registerPushToken(token, Platform.isIOS ? 'IOS' : 'ANDROID');
    }
  } catch (_) {
    // Token registration retries on next launch; permission itself succeeded.
  }
  return 'granted';
}
