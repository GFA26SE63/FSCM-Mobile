import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fscm_mobile/app/app.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      <DeviceOrientation>[DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final customUrl = prefs.getString('custom_api_base_url');
  if (customUrl != null && customUrl.trim().isNotEmpty) {
    Env.setRuntimeApiBaseUrl(customUrl.trim());
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FscmApp(),
    ),
  );
}
