import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/main.dart';

void main() {
  testWidgets('Nixin Studio shell renders', (tester) async {
    await tester.pumpWidget(const NixinApp());

    expect(find.text('Nixin Studio V8'), findsOneWidget);
    expect(find.text('Open RAW'), findsOneWidget);
  });
}
