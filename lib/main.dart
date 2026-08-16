import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/nixin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<dynamic>('studio_settings'),
    Hive.openBox<dynamic>('workplaces'),
    Hive.openBox<dynamic>('assets'),
  ]);

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('th')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const NixinApp(),
      ),
    ),
  );
}
