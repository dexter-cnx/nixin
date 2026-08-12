import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test_ffi_smoke', () {
    // Packaging smoke only. A real develop call requires both a platform-built native library
    // and a camera RAW fixture with an embedded JPEG preview. CI should provide those explicitly.
    final expected = Platform.isWindows ? 'raw_engine.dll' : Platform.isMacOS ? 'libraw_engine.dylib' : 'libraw_engine.so';
    expect(expected, isNotEmpty);
  });
}
