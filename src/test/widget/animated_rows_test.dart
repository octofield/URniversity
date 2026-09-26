import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/theme/app_motion.dart';
import 'package:urniversity/widgets/animated_rows.dart';

// AnimatedRows (system_design.md §3-Q): rows arrive and leave instead of
// popping, a leaving row can be held on screen first, and none of it happens
// when the system asks for no motion
void main() {
  // A host whose rows the test can change between builds
  Future<ValueNotifier<List<String>>> pumpRows(
    WidgetTester tester, {
    List<String> initial = const ['a', 'b', 'c'],
    Duration hold = Duration.zero,
    Duration enterDelay = Duration.zero,
    bool reduceMotion = false,
  }) async {
    final rows = ValueNotifier<List<String>>(initial);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: ValueListenableBuilder<List<String>>(
            valueListenable: rows,
            builder: (_, ids, _) => AnimatedRows(
              separatorBuilder: (_, _) => const Divider(height: 1),
              holdFor: (_) => hold,
              enterDelayFor: (_) => enterDelay,
              children: [
                for (final id in ids) _Row(key: ValueKey(id), id: id),
              ],
            ),
          ),
        ),
      ),
    ));
    return rows;
  }

  testWidgets('the first build shows every row at once', (tester) async {
    await pumpRows(tester);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a removed row is held, then folds away', (tester) async {
    final rows = await pumpRows(tester, hold: AppMotion.hold);

    rows.value = ['a', 'c'];
    await tester.pump();
    await tester.pump(AppMotion.hold - const Duration(milliseconds: 50));
    expect(find.text('b'), findsOneWidget, reason: 'still held on screen');
    final held = tester.getSize(find.byKey(const ValueKey('b')).first);
    expect(held.height, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.text('b'), findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('a leaving row takes no taps', (tester) async {
    final rows = await pumpRows(tester, hold: AppMotion.hold);
    rows.value = ['a', 'c'];
    await tester.pump();

    await tester.tap(find.text('b'), warnIfMissed: false);
    expect(_Row.taps, isNot(contains('b')));
  });

  testWidgets('a new row unfolds into place', (tester) async {
    final rows = await pumpRows(tester);

    rows.value = ['a', 'b', 'new', 'c'];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final early = tester.getSize(find.byKey(const ValueKey('new')).first).height;
    await tester.pumpAndSettle();
    final settled = tester.getSize(find.byKey(const ValueKey('new')).first).height;
    expect(early, lessThan(settled));
  });

  testWidgets('rows that stay keep their state', (tester) async {
    final rows = await pumpRows(tester);
    final before = tester.state(find.byType(_Row).first);

    rows.value = ['a', 'c', 'd'];
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_Row).first), same(before));
  });

  testWidgets('a row that comes straight back is not lost', (tester) async {
    final rows = await pumpRows(tester, hold: AppMotion.hold);

    rows.value = ['a', 'c'];
    await tester.pump(const Duration(milliseconds: 100));
    rows.value = ['a', 'b', 'c'];
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('with no motion asked for, rows simply go', (tester) async {
    final rows = await pumpRows(tester, hold: AppMotion.hold, reduceMotion: true);

    rows.value = ['a', 'c'];
    await tester.pump();
    await tester.pump();
    expect(find.text('b'), findsNothing);
  });
}

class _Row extends StatefulWidget {
  final String id;
  const _Row({super.key, required this.id});

  static final taps = <String>[];

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(widget.id),
        onTap: () => _Row.taps.add(widget.id),
      );
}
