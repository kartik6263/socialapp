import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'api/client.dart';
import 'app.dart';
import 'i18n/i18n.dart';
import 'state/auth.dart';
import 'state/toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initDeviceHeaders();

  final i18n = I18n();
  final auth = AuthState();
  await i18n.load();
  // Restores the saved session in the background; the splash screen shows until it's ready.
  auth.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: i18n),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ToastController()),
      ],
      child: PlansApp(auth: auth),
    ),
  );
}
