import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/app/router/app_router.dart';

void main() {
  test('router starts at the Studio route', () {
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.studio);
  });
}
