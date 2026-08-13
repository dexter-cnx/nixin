import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/app/theme/studio_theme.dart';
import 'package:nixin_studio_v8/studio/preview_surface.dart';
import 'package:nixin_studio_v8/studio/studio_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders empty preview state', (tester) async {
    await _pumpPreview(tester, const StudioState());

    expect(find.byIcon(Icons.photo_size_select_actual_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders processing overlay', (tester) async {
    await _pumpPreview(
      tester,
      const StudioState(previewStatus: PreviewStatus.processing),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders explicit error state', (tester) async {
    await _pumpPreview(
      tester,
      const StudioState(
        previewStatus: PreviewStatus.error,
        errorMessage: 'engine failure',
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('engine failure'), findsOneWidget);
  });

  testWidgets('renders ready image and switches to 1:1 viewer', (tester) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    await _pumpPreview(
      tester,
      StudioState(
        previewStatus: PreviewStatus.ready,
        previewPng: png,
        imageWidth: 1,
        imageHeight: 1,
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);

    await _pumpPreview(
      tester,
      StudioState(
        previewStatus: PreviewStatus.ready,
        previewPng: png,
        imageWidth: 1,
        imageHeight: 1,
        previewZoomMode: PreviewZoomMode.oneToOne,
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}

Future<void> _pumpPreview(WidgetTester tester, StudioState state) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'test',
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      assetLoader: const _TestAssetLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          theme: StudioTheme.dark,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: StudioPreviewSurface(
              state: state,
              onZoomModeChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => const {
        'preview': {
          'processing': 'Processing',
          'error': 'Preview error',
          'empty_title': 'No image selected',
          'empty_body': 'Open a RAW file to begin',
          'fit': 'Fit',
          'one_to_one': '1:1',
        },
      };
}
