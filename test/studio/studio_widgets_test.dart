import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/app/theme/studio_theme.dart';
import 'package:nixin_studio_v8/studio/studio_widgets.dart';

void main() {
  testWidgets('panel section collapses and restores its content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(
          body: StudioPanelSection(
            title: 'Tools',
            child: Text('Develop action'),
          ),
        ),
      ),
    );

    final content = find.text('Develop action');

    expect(content, findsOneWidget);
    expect(content.hitTestable(), findsOneWidget);

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    // AnimatedCrossFade intentionally keeps both children in the widget tree.
    // A collapsed section should make its content non-interactive rather than
    // requiring the child to be removed from the tree.
    expect(content, findsOneWidget);
    expect(content.hitTestable(), findsNothing);

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    expect(content, findsOneWidget);
    expect(content.hitTestable(), findsOneWidget);
  });

  testWidgets('disabled action button does not invoke callback', (tester) async {
    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark,
        home: Scaffold(
          body: ActionButton(
            icon: Icons.tune,
            label: 'Develop',
            onPressed: null,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Develop'));
    await tester.pump();

    expect(invoked, isFalse);
  });
}
