@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The web bug behind row_id_test.dart was invisible to every VM test: `1 << 32`
// is 4294967296 on the VM and 0 on the web, and catching it for real needs a
// browser run, which is slow and needs Chrome installed. This reads the source
// instead, so the shift cannot come back unnoticed.
void main() {
  test('the row id suffix range is a literal, not a shift', () {
    // Comment lines are dropped first: the one explaining this bug names the
    // very expression being looked for
    final code = File('lib/providers/synced_list_notifier.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .toList();

    expect(code.any((line) => line.contains('0x100000000')), isTrue);
    expect(
      code.any((line) => line.contains('<< 32')),
      isFalse,
      reason: 'a shift past bit 31 is 0 on the web, and nextInt(0) throws',
    );
  });
}
