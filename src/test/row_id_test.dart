import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/synced_list_notifier.dart';

// Row ids must be makeable on every platform the app ships to. On the web every
// int is a JavaScript number and `<<` works on 32 bits, so `1 << 32` came out
// as 0 and Random.nextInt(0) threw — adding any task, goal or vision failed in
// the browser while every VM test passed.
//
// Run on both: `flutter test test/row_id_test.dart` and
// `flutter test --platform chrome test/row_id_test.dart`
void main() {
  test('a row id can be made', () {
    final parts = newRowId().split('_');
    expect(parts, hasLength(2));
    expect(int.parse(parts.first), greaterThan(0));
  });

  test('the random suffix stays within 32 bits', () {
    for (var i = 0; i < 200; i++) {
      final suffix = int.parse(newRowId().split('_').last);
      expect(suffix, inInclusiveRange(0, 0xFFFFFFFF));
    }
  });
}
