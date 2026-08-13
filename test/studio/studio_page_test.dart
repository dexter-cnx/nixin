import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/app/theme/studio_theme.dart';
import 'package:nixin_studio_v8/engine/engine_image.dart';
import 'package:nixin_studio_v8/engine/raw_engine.dart';
import 'package:nixin_studio_v8/studio/filmstrip.dart';
import 'package:nixin_studio_v8/studio/studio_controller.dart';
import 'package:nixin_studio_v8/studio/studio_page.dart';
import 'package:nixin_studio_v8/studio/studio_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _mockSharedPreferences();
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('studio actions are disabled until an image is selected', (tester) async {
    final container = await _pumpStudio(tester, width: 1200, height: 800);
    addTearDown(container.dispose);

    FilledButton developButton() {
      final finder = find.ancestor(
        of: find.byIcon(Icons.developer_board_outlined),
        matching: find.byType(FilledButton),
      );
      return tester.widget<FilledButton>(finder);
    }

    expect(developButton().onPressed, isNull);

    container
        .read(studioControllerProvider.notifier)
        .selectRawPath('/tmp/sample.nef');
    await tester.pump();

    expect(developButton().onPressed, isNotNull);
  });

  testWidgets('workspace selects wide, medium, and compact compositions by width',
      (tester) async {
    final wide = await _pumpStudio(tester, width: 1200, height: 800);
    addTearDown(wide.dispose);
    expect(find.byType(StudioPanel), findsNWidgets(2));
    expect(find.byType(StudioFilmstrip), findsOneWidget);

    final medium = await _pumpStudio(tester, width: 900, height: 800);
    addTearDown(medium.dispose);
    expect(find.byType(StudioPanel), findsOneWidget);
    expect(find.byType(StudioFilmstrip), findsOneWidget);

    final compact = await _pumpStudio(tester, width: 700, height: 800);
    addTearDown(compact.dispose);
    expect(find.byType(StudioPanel), findsNothing);
    expect(find.byType(StudioFilmstrip), findsNothing);
    expect(find.byType(StudioStatusBar), findsNothing);
  });

  testWidgets('develop adjustment sections are available in the right panel',
      (tester) async {
    final container = await _pumpStudio(tester, width: 1200, height: 900);
    addTearDown(container.dispose);

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.text('Contrast'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Reset adjustments'), findsOneWidget);
  });

  testWidgets('Tab toggles side panels and Shift+Tab toggles chrome',
      (tester) async {
    final container = await _pumpStudio(tester, width: 1200, height: 800);
    addTearDown(container.dispose);

    expect(container.read(studioControllerProvider).leftPanelVisible, isTrue);
    expect(container.read(studioControllerProvider).rightPanelVisible, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(container.read(studioControllerProvider).leftPanelVisible, isFalse);
    expect(container.read(studioControllerProvider).rightPanelVisible, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(container.read(studioControllerProvider).chromeVisible, isFalse);
    expect(find.byType(StudioFilmstrip), findsNothing);
    expect(find.byType(StudioStatusBar), findsNothing);
  });
}

void _mockSharedPreferences() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return true;
    },
  );
}

Future<ProviderContainer> _pumpStudio(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final container = ProviderContainer(
    overrides: [
      studioEngineProvider.overrideWithValue(_FakeEngine()),
      studioSettingsStoreProvider.overrideWithValue(_MemorySettings()),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
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
            home: const StudioPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => const {
        'app_name': 'Nixin',
        'module': {
          'library': 'Library',
          'develop': 'Develop',
          'export': 'Export',
        },
        'panel': {
          'navigator': 'Navigator',
          'presets': 'Presets',
          'tools': 'Tools',
          'light': 'Light',
          'color': 'Color',
          'export': 'Export',
          'filmstrip': 'Filmstrip',
        },
        'action': {
          'open_raw': 'Open Image',
          'apply_lut': 'Apply LUT',
          'develop': 'Develop',
          'subject_mask': 'Subject Mask',
          'sky_mask': 'Sky Mask',
          'reset_adjustments': 'Reset adjustments',
          'export_jpeg': 'Export JPEG',
          'show_filmstrip': 'Show Filmstrip',
          'hide_filmstrip': 'Hide Filmstrip',
        },
        'adjustment': {
          'exposure': 'Exposure',
          'contrast': 'Contrast',
          'temperature': 'Temperature',
        },
        'settings': {'jpeg_quality': 'JPEG Quality'},
        'preview': {
          'processing': 'Processing',
          'error': 'Preview error',
          'empty_title': 'No image selected',
          'empty_body': 'Open an image to begin',
          'fit': 'Fit',
          'one_to_one': '1:1',
        },
        'label': {
          'filmstrip_empty': 'Open an image',
          'no_file': 'No file',
          'engine': 'Engine',
        },
        'status': {
          'ready': 'Ready',
          'engine_unavailable': 'Engine unavailable',
          'selected': 'Selected',
          'exported': 'Exported',
        },
      };
}

class _MemorySettings implements StudioSettingsStore {
  final Map<String, Object> values = {};

  @override
  T read<T>(String key, T defaultValue) =>
      (values[key] ?? defaultValue) as T;

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }
}

class _FakeEngine implements StudioEngine {
  EngineImage get _image => EngineImage(
        Uint8List.fromList(const [32, 64, 96, 255]),
        1,
        1,
      );

  @override
  EngineImage? applyLut(String path, String lutPath, double strength) => _image;

  @override
  bool checkEngine() => true;

  @override
  EngineImage? develop(
    String path, {
    double exposure = 0,
    double temperature = 0,
    double contrast = 1,
  }) => _image;

  @override
  String? exportJpeg(
    String path,
    String dest,
    int quality, {
    double exposure = 0,
    double temperature = 0,
    double contrast = 1,
  }) => dest;

  @override
  String lastError() => 'fake engine error';

  @override
  EngineImage? skyMask(String path) => _image;

  @override
  EngineImage? subjectMask(String path, {int? x, int? y}) => _image;

  @override
  String version() => 'fake-1.0';
}
