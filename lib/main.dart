import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fscm_mobile/app/app.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/data/local/database_factory.dart';
import 'package:fscm_mobile/data/mock/mock_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  await SystemChrome.setPreferredOrientations(
      <DeviceOrientation>[DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Mock mode (default) serves the REST API in-process; real mode keeps
        // the Dio transport configured in api_client.dart.
        if (Env.useMock) apiTransportProvider.overrideWithValue(MockApi()),
      ],
      child: const FscmApp(),
    ),
  );
}
