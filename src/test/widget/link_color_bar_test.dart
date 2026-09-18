import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/widgets/link_color_bar.dart';

// The stripe down the left edge of a task or goal row. Two colours is how a row
// says it is linked to something whose colour differs from its own.
void main() {
  Future<void> pumpBar(WidgetTester tester, LinkColorBar bar) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(height: 40, child: bar))));

  List<Color?> paintedColours(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.color)
      .toList();

  testWidgets('two different links paint two colours', (tester) async {
    await pumpBar(tester, const LinkColorBar(top: Colors.red, bottom: Colors.blue));
    expect(paintedColours(tester), [Colors.red, Colors.blue]);
  });

  testWidgets('the same colour twice stays one band', (tester) async {
    await pumpBar(tester, const LinkColorBar(top: Colors.red, bottom: Colors.red));
    expect(paintedColours(tester), [Colors.red]);
  });

  testWidgets('one link paints one colour', (tester) async {
    await pumpBar(tester, const LinkColorBar(top: Colors.red));
    expect(paintedColours(tester), [Colors.red]);
  });

  testWidgets('no link still holds the width, so rows stay aligned', (tester) async {
    await pumpBar(tester, const LinkColorBar(width: 6));
    expect(paintedColours(tester), isEmpty);
    expect(tester.getSize(find.byType(LinkColorBar)).width, 6);
  });
}
