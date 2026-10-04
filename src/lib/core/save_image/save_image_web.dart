import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// A link to the bytes, clicked once, then let go
Future<void> savePng(Uint8List png, String fileName) async {
  final blob = web.Blob([png.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
}
