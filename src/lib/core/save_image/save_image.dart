import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart' show GlobalKey;

import 'save_image_io.dart' if (dart.library.js_interop) 'save_image_web.dart' as impl;

// Hands a PNG to the user: the share sheet on a phone (save to photos, send
// it on), a download on the web. Replaceable so tests need neither
Future<void> Function(Uint8List png, String fileName) savePng = impl.savePng;

// What a RepaintBoundary under [key] shows, as PNG bytes at three times the
// screen's resolution. Null when it is not on screen. Replaceable in tests:
// capturing needs the real event loop, where google_fonts would try the network
Future<Uint8List?> Function(GlobalKey key) capturePng = (key) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
};
