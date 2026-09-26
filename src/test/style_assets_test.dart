import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/theme/app_styles.dart';

// The style's Android side — launcher icons, splash themes, widget colours —
// is generated from scripts/style_assets/palettes.json (system_design.md
// §3-R). These keep that copy, the generated files and the Kotlin lists in
// step with kStylePalettes, so changing a colour in Dart without re-running the
// script fails here rather than on someone's home screen
void main() {
  const res = 'android/app/src/main/res';
  String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  final json = jsonDecode(File('../scripts/style_assets/palettes.json').readAsStringSync()) as Map<String, dynamic>;
  final generated = AppStyle.values.where((s) => s != AppStyle.linen);

  test('palettes.json matches kStylePalettes', () {
    expect(json.keys, AppStyle.values.map((s) => s.name));
    for (final style in AppStyle.values) {
      final p = kStylePalettes[style]!;
      final j = json[style.name] as Map<String, dynamic>;
      final expected = {
        'background': p.background, 'surface': p.surface, 'surfaceVariant': p.surfaceVariant,
        'primary': p.primary, 'primaryLight': p.primaryLight, 'primaryDark': p.primaryDark,
        'textPrimary': p.textPrimary, 'textSecondary': p.textSecondary,
        'textTertiary': p.textTertiary, 'border': p.border,
      };
      for (final e in expected.entries) {
        expect(j[e.key], hex(e.value), reason: '${style.name}.${e.key}');
      }
      expect(j['brightness'], p.brightness == Brightness.dark ? 'dark' : 'light', reason: style.name);
    }
  });

  test('the widget colours were generated from the current palettes', () {
    final xml = File('$res/values/widget_style_colors.xml').readAsStringSync();
    for (final style in generated) {
      final p = kStylePalettes[style]!;
      for (final (role, colour) in [
        ('background', p.background), ('border', p.border), ('text', p.textPrimary),
        ('accent', p.primary), ('muted', p.textTertiary), ('box', p.textSecondary),
      ]) {
        expect(xml, contains('<color name="widget_${role}_${style.name}">${hex(colour)}</color>'),
            reason: '${style.name} $role');
      }
    }
  });

  test('every style has its icon, splash logo and widget drawables', () {
    for (final style in generated) {
      final n = style.name;
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(File('$res/drawable-$d/ic_launcher_foreground_$n.png').existsSync(), isTrue, reason: '$n $d');
        expect(File('$res/mipmap-$d/ic_launcher_$n.png').existsSync(), isTrue, reason: '$n $d');
        expect(File('$res/drawable-$d/splash_logo_$n.png').existsSync(), isTrue, reason: '$n $d');
      }
      expect(File('$res/mipmap-anydpi-v26/ic_launcher_$n.xml').existsSync(), isTrue);
      for (final part in ['background', 'add_pill', 'check', 'check_on', 'check_off', 'check_anim_on', 'check_anim_off']) {
        expect(File('$res/drawable/widget_${part}_$n.xml').existsSync(), isTrue, reason: '$n $part');
      }
    }
  });

  test('every style has a launcher alias, a splash theme and a widget look', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final themes = File('$res/values-v31/launch_styles.xml').readAsStringSync();
    const kotlin = 'android/app/src/main/kotlin/com/octofield/urniversity';
    final widget = File('$kotlin/WidgetStyle.kt').readAsStringSync();
    final activity = File('$kotlin/MainActivity.kt').readAsStringSync();

    for (final style in AppStyle.values) {
      final cap = style.name[0].toUpperCase() + style.name.substring(1);
      expect(manifest, contains('android:name=".Style$cap"'), reason: style.name);
      if (style == AppStyle.linen) continue;
      expect(themes, contains('name="LaunchTheme.$cap"'), reason: style.name);
      expect(widget, contains('"${style.name}" ->'), reason: style.name);
      expect(activity, contains('R.style.LaunchTheme_$cap'), reason: style.name);
    }
    // MainActivity's list mirrors AppStyle, first entry the default
    final names = AppStyle.values.map((s) => '"${s.name}"').join(', ');
    expect(activity, contains('listOf($names)'));
  });

  test('only the original icon is enabled out of the box', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final enabled = RegExp(r'<activity-alias[^>]*android:enabled="true"').allMatches(manifest);
    expect(enabled, hasLength(1));
    expect(enabled.single.group(0), contains('.StyleLinen'));
  });
}
