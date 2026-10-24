import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import '../helpers/pump_app.dart';

// Text selectable with the mouse on a computer (system_design.md §3-F,
// 2026-10-24): every page, dialog and sheet; Ctrl+C copies. Phones are left
// as they were
void main() {
  const zh = StringsZhTw();
  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  setUp(() => setUpTestSupabase());

  // The clipboard answered without a platform behind it
  void quietClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> copy(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('a task\'s title is dragged over with the mouse and copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final c = await pumpApp(tester, width: 1280);
    c.read(tasksProvider.notifier).add('交期末報告');
    await tester.pumpAndSettle();

    // The one on screen: the other task views are there too, hidden
    final title = find.text('交期末報告').hitTestable().first;
    final box = tester.getRect(title);
    await mouseDrag(tester, box.centerLeft - const Offset(2, 0), box.centerRight + const Offset(2, 0));
    await copy(tester);
    expect(copied, contains('交期末報告'));
  }, variant: desktop);

  testWidgets('on a tab with others kept alive under it, the shown one is what gets copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpApp(tester, width: 1280);
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();
    final heading = find.text(zh.inspirations).hitTestable().first;
    final box = tester.getRect(heading);
    await mouseDrag(tester, box.centerLeft - const Offset(2, 0), box.centerRight + const Offset(2, 0));
    await copy(tester);
    expect(copied, contains(zh.inspirations));
  }, variant: desktop);

  testWidgets('clicks still click: a task is ticked off', (tester) async {
    quietClipboard(tester);
    final c = await pumpApp(tester, width: 1280);
    c.read(tasksProvider.notifier).add('寄信給助教');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(c.read(tasksProvider).single.isCompleted, isTrue);
  }, variant: desktop);

  testWidgets('rearranging still drags rows by their handle with the mouse', (tester) async {
    quietClipboard(tester);
    final c = await pumpApp(tester, width: 1280);
    c.read(tasksProvider.notifier).add('第一件');
    c.read(tasksProvider.notifier).add('第二件');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(zh.sortBy));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.sortRearrange));
    await tester.pumpAndSettle();

    // The row picks up (its copy follows the pointer) rather than the text
    // under it being selected
    final handle = tester.getCenter(find.byIcon(Icons.drag_handle).first);
    expect(find.text('第二件'), findsOneWidget);
    final gesture = await tester.startGesture(handle, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(handle + Offset(0, i * 8.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('第二件'), findsNWidgets(2));
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: desktop);

  testWidgets('a phone has no selection area at all', (tester) async {
    await pumpApp(tester);
    expect(find.byType(SelectionArea), findsNothing);
  });
}
