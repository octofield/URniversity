import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/save_image/save_image.dart';

// The timetable's export (2026-10-03): what is under the key comes out as a PNG
void main() {
  testWidgets('a boundary on screen becomes PNG bytes; one that is not, nothing', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Center(
      child: RepaintBoundary(key: key, child: const SizedBox(width: 40, height: 20, child: ColoredBox(color: Colors.teal))),
    ));
    final png = await tester.runAsync(() => capturePng(key));
    expect(png!.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(await tester.runAsync(() => capturePng(GlobalKey())), isNull);
  });
}
