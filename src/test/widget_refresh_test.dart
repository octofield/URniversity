import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/services/home_widget_background.dart';
import 'package:urniversity/services/home_widget_service.dart';

// The widget's refresh (system_design.md §3-M, 2026-10-10): its button, and
// its half-hourly update once the snapshot is stale, ask the background engine
// for a fresh snapshot. Pushed with a time stamp, which is what keeps a push —
// that itself fires the update — from asking again
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  final saved = <String, Object?>{};

  setUp(() {
    saved.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveWidgetData') {
        final args = call.arguments as Map;
        saved[args['id'] as String] = args['data'];
      }
      return true;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('refresh rebuilds the snapshot from what is stored now, and stamps it', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'is_guest_mode': true,
      'guest_tasks': jsonEncode([
        Task(id: 't1', title: '剛從別處加的', createdAt: now, dueTime: DateTime(now.year, now.month, now.day, 23)).toJson(),
      ]),
    });
    final before = DateTime.now().millisecondsSinceEpoch;
    await applyWidgetAction(Uri.parse('urniversity://refresh'));

    final snapshot = saved[HomeWidgetService.snapshotKey] as String?;
    expect(snapshot, isNotNull, reason: 'a snapshot was pushed');
    expect(snapshot, contains('剛從別處加的'));
    final stamp = int.parse(saved[HomeWidgetService.pushedAtKey] as String);
    expect(stamp, greaterThanOrEqualTo(before));
  });

}
