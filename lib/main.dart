import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/nixin_app.dart';
import 'storage/hive/hive_app_storage.dart';
import 'storage/storage_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final storage = await HiveAppStorage.open();

  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('th')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const NixinApp(),
      ),
    ),
  );
}
