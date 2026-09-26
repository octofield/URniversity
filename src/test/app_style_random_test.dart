import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/core/theme/app_styles.dart';
import 'package:urniversity/providers/app_style_provider.dart';

// Random style (system_design.md §3-R): a different style every cold start,
// never the same twice in a row, and the one drawn ahead for the next launch
// is the one that launch wears — Android 13+ has already shown its splash
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pickStyle never returns the one excluded', () {
    final rng = Random(1);
    for (final except in AppStyle.values) {
      for (var i = 0; i < 50; i++) {
        expect(pickStyle(rng, except: except), isNot(except));
      }
    }
  });

  test('fifty cold starts: never a repeat, and every style turns up', () async {
    SharedPreferences.setMockInitialValues({AppStyleNotifier.key: kRandomStyle});
    final rng = Random(7);
    final seen = <AppStyle>{};
    AppStyle? previous;
    for (var i = 0; i < 50; i++) {
      await preloadAppStyle(rng: rng);
      expect(launchStyle, isNot(previous), reason: 'launch $i');
      seen.add(launchStyle);
      previous = launchStyle;
    }
    expect(seen, containsAll(AppStyle.values));
  });

  test('the style drawn ahead is the one the next launch wears', () async {
    SharedPreferences.setMockInitialValues({AppStyleNotifier.key: kRandomStyle});
    await preloadAppStyle(rng: Random(3));
    final prefs = await SharedPreferences.getInstance();
    final planned = prefs.getString(AppStyleNotifier.nextKey);
    expect(planned, isNot(launchStyle.name));

    await preloadAppStyle(rng: Random(99));
    expect(launchStyle.name, planned);
  });

  test('a missing or repeating plan is drawn again', () {
    final missing = resolveRandomLaunch(next: null, last: 'ocean', rng: Random(1));
    expect(missing.now, isNot(AppStyle.ocean));
    final repeat = resolveRandomLaunch(next: 'ocean', last: 'ocean', rng: Random(1));
    expect(repeat.now, isNot(AppStyle.ocean));
    final unknown = resolveRandomLaunch(next: 'neon', last: null, rng: Random(1));
    expect(AppStyle.values, contains(unknown.now));
    expect(unknown.next, isNot(unknown.now));
  });

  test('a fixed choice is simply worn', () async {
    SharedPreferences.setMockInitialValues({AppStyleNotifier.key: 'sage'});
    await preloadAppStyle();
    expect(launchStyle, AppStyle.sage);
  });

  test('choosing random changes the style at once and remembers the choice', () async {
    SharedPreferences.setMockInitialValues({AppStyleNotifier.key: 'modern'});
    await preloadAppStyle();
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await c.read(appStyleProvider.notifier).setRandom(rng: Random(5));
    expect(c.read(appStyleProvider), isNot(AppStyle.modern));
    expect(c.read(appStyleChoiceProvider), kRandomStyle);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppStyleNotifier.key), kRandomStyle);
    expect(prefs.getString(AppStyleNotifier.lastKey), c.read(appStyleProvider).name);
  });

  test('a choice synced from another device is applied', () async {
    SharedPreferences.setMockInitialValues({});
    await preloadAppStyle();
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await c.read(appStyleProvider.notifier).applyChoice('mono');
    expect(c.read(appStyleProvider), AppStyle.mono);
    await c.read(appStyleProvider.notifier).applyChoice(kRandomStyle);
    expect(c.read(appStyleChoiceProvider), kRandomStyle);
  });
}
