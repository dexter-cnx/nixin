import 'dart:typed_data';

class EngineImage {
  const EngineImage(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}
