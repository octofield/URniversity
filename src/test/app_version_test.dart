@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/app_version.dart';

// One version, two files: the string the settings screen shows and the
// `version:` pubspec.yaml ships with. They drifted before there was a constant
// at all — the screen said alpha-1.0 while pubspec said 1.0.0+1.
void main() {
  test('the version is alpha-prefixed X.X.X', () {
    expect(RegExp(r'^alpha-\d+\.\d+\.\d+$').hasMatch(kAppVersion), isTrue,
        reason: 'got $kAppVersion');
  });

  test('pubspec carries the same numbers', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final numbers = kAppVersion.split('-').last;

    expect(line, startsWith('version: $numbers+'),
        reason: 'pubspec says "$line", the app says $kAppVersion');
  });
}
