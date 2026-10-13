import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's real fonts (instead of the square test font) so layout tests measure text as phones do.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const families = [
    'Manrope_700Bold', 'Manrope_800ExtraBold', 'DMSans_400Regular', 'DMSans_500Medium', 'DMSans_600SemiBold', 'DMSans_700Bold', 'Feather',
  ];
  for (final f in families) {
    final bytes = File('assets/fonts/$f.ttf').readAsBytesSync();
    final loader = FontLoader(f)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  await testMain();
}
