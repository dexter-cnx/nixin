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

  testWidgets('studio actions are disabled until a RAW is selected', (tester) async {
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
    var container = await _pumpStudio(tester, width: 1200, height: 800);
    addTearDown(container.dispose);
    expect(find.byType(StudioPanel), findsNWidgets(2));
    expect(find.byType(StudioFilmstrip), findsOneWidget);

    container.dispose();
    container = await _pumpStudio(tester, width: 900, height: 800);
    expect(find.byType(StudioPanel), findsOneWidget);
    expect(find.byType(StudioFilmstrip), findsOneWidget);

    container.dispose();
    container = await _pumpStudio(tester, width: 700, height: 800);
    expect(find.byType(StudioPanel), findsNothing);
    expect(find.byType(StudioFilmstrip), findsNothing);
    expect(find.byType(StudioStatusBar), findsNothing);
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
          'export': 'Export',
          'filmstrip': 'Filmstrip',
        },
        'action': {
          'open_raw': 'Open RAW',
          'apply_lut': 'Apply LUT',
          'develop': 'Develop',
          'subject_mask': 'Subject Mask',
          'sky_mask': 'Sky Mask',
          'export_jpeg': 'Export JPEG',
          'show_filmstrip': 'Show Filmstrip',
          'hide_filmstrip': 'Hide Filmstrip',
        },
        'settings': {'jpeg_quality': 'JPEG Quality'},
        'preview': {
          'processing': 'Processing',
          'error': 'Preview error',
          'empty_title': 'No image selected',
          'empty_body': 'Open a RAW file to begin',
          'fit': 'Fit',
          'one_to_one': '1:1',
        },
        'label': {
          'filmstrip_empty': 'Open a RAW file',
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
  EngineImage? develop(String path) => _image;

  @override
  String? exportJpeg(String path, String dest, int quality) => dest;

  @override
  String lastError() => 'fake engine error';

  @override
  EngineImage? skyMask(String path) => _image;

  @override
  EngineImage? subjectMask(String path, {int? x, int? y}) => _image;

  @override
  String version() => 'fake-1.0';
}
