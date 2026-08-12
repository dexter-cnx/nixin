import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../studio/studio_page.dart';
import 'theme/studio_theme.dart';

class NixinApp extends StatelessWidget {
  const NixinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nixin Studio V8',
      theme: StudioTheme.dark,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const StudioPage(),
    );
  }
}
