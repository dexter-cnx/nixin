import 'package:go_router/go_router.dart';

import '../../studio/studio_page.dart';

abstract final class AppRoutes {
  static const studio = '/';
  static const studioName = 'studio';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.studio,
  routes: [
    GoRoute(
      path: AppRoutes.studio,
      name: AppRoutes.studioName,
      builder: (context, state) => const StudioPage(),
    ),
  ],
);
