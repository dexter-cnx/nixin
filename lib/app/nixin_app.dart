import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workplaces/application/catalog_read_projection_sync.dart';
import 'router/app_router.dart';
import 'theme/studio_theme.dart';

class NixinApp extends ConsumerWidget {
  const NixinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(catalogReadProjectionSyncProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Dextryx Images',
      theme: StudioTheme.dark,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: appRouter,
    );
  }
}
