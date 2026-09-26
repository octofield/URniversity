import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/core/theme/app_colors.dart';
import 'package:urniversity/core/theme/app_styles.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/app_style_provider.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/widgets/sheet_body.dart';

import '../helpers/pump_app.dart';

// Styles (system_design.md §3-R): picked from Settings, applied to everything
// already on screen without losing where the user is, remembered, and every
// one of them able to draw the whole app
void main() {
  const zh = StringsZhTw();

  // The launch style is module state too: start every test from linen
  setUp(() async {
    await setUpTestSupabase();
    await preloadAppStyle();
  });
  // AppColors is global; a test that changes style must not leak it
  tearDown(() => AppColors.use(kStylePalettes[AppStyle.linen]!));

  // The soft wash at the top of the home screen, drawn from AppColors
  Color homeWash(WidgetTester tester) {
    // The only top-to-bottom gradient; the add buttons' run corner to corner
    final box = tester.widget<DecoratedBox>(find.byWidgetPredicate((w) {
      if (w is! DecoratedBox || w.decoration is! BoxDecoration) return false;
      final gradient = (w.decoration as BoxDecoration).gradient;
      return gradient is LinearGradient && gradient.begin == Alignment.topCenter;
    }));
    return ((box.decoration as BoxDecoration).gradient! as LinearGradient).colors.first;
  }

  testWidgets('Settings lists every style and applies the one picked', (tester) async {
    final c = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text(zh.appStyle));
    await tester.pumpAndSettle();
    for (final name in [
      zh.styleLinen, zh.styleModern, zh.styleMidnight, zh.styleSage,
      zh.styleOcean, zh.styleSakura, zh.styleMono,
    ]) {
      expect(find.text(name), findsWidgets, reason: name);
    }

    await tester.tap(find.text(zh.styleMidnight).last);
    await tester.pumpAndSettle();

    expect(c.read(appStyleProvider), AppStyle.midnight);
    expect(AppColors.background, kStylePalettes[AppStyle.midnight]!.background);
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness, Brightness.dark);
    // Still where the user was: Settings, with the picker open over it
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(zh.styleSakura), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppStyleNotifier.key), 'midnight');
  });

  testWidgets('what is already on screen takes the new style', (tester) async {
    final c = await pumpApp(tester);
    expect(homeWash(tester), kStylePalettes[AppStyle.linen]!.primaryLight);

    await c.read(appStyleProvider.notifier).set(AppStyle.ocean);
    await tester.pumpAndSettle();
    expect(homeWash(tester), kStylePalettes[AppStyle.ocean]!.primaryLight);
  });

  testWidgets('even a const widget that depends on nothing is repainted', (tester) async {
    // The sheet's drag handle is const and reads only AppColors: no theme or
    // provider change would rebuild it. Only the full-tree rebuild reaches it
    final c = await pumpApp(tester);
    await tester.tap(find.byTooltip(zh.addTask));
    await tester.pumpAndSettle();
    Color handle() => ((tester.widget<Container>(
      find.descendant(of: find.byType(SheetDragHandle), matching: find.byType(Container)),
    ).decoration!) as BoxDecoration).color!;
    expect(handle(), kStylePalettes[AppStyle.linen]!.border);

    await c.read(appStyleProvider.notifier).set(AppStyle.midnight);
    await tester.pumpAndSettle();
    expect(handle(), kStylePalettes[AppStyle.midnight]!.border);
  });

  testWidgets('the old look dissolves into the new one', (tester) async {
    final c = await pumpApp(tester);
    Finder snapshot() => find.byType(RawImage);
    expect(snapshot(), findsNothing);

    await c.read(appStyleProvider.notifier).set(AppStyle.modern);
    await tester.pump();
    expect(snapshot(), findsOneWidget, reason: 'the old frame is laid over the new one');

    await tester.pumpAndSettle();
    expect(snapshot(), findsNothing, reason: 'and cleared once faded');
  });

  testWidgets('the style is remembered for the next launch', (tester) async {
    final c = await pumpApp(tester);
    await c.read(appStyleProvider.notifier).set(AppStyle.mono);

    await preloadAppStyle();
    final fresh = testContainer();
    expect(fresh.read(appStyleProvider), AppStyle.mono);
  });

  // What the app told Android: the icon and splash (MainActivity.kt) and the
  // style written for the home screen widget
  ({List<String> style, List<String> widget}) recordPlatform(WidgetTester tester) {
    final style = <String>[];
    final widget = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('urniversity/style'), (call) async {
      style.add('${call.method}:${(call.arguments as Map)['style']}');
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      final args = call.arguments;
      if (call.method != 'saveWidgetData') return null;
      if (args is Map && args['id'] == 'app_style') widget.add(args['data'] as String);
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('urniversity/style'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    });
    return (style: style, widget: widget);
  }

  testWidgets('a style picked by hand changes the icon and the next splash', (tester) async {
    final calls = recordPlatform(tester);
    final c = await pumpApp(tester);

    await c.read(appStyleProvider.notifier).set(AppStyle.ocean);
    await tester.pumpAndSettle();
    expect(calls.style, containsAll(['setIcon:ocean', 'setSplash:ocean']));
    expect(calls.widget, contains('ocean'), reason: 'the widget follows');
  });

  testWidgets('random changes the look but never the icon', (tester) async {
    final calls = recordPlatform(tester);
    final c = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.appStyle));
    await tester.pumpAndSettle();

    final before = c.read(appStyleProvider);
    await tester.tap(find.text(zh.styleRandom));
    await tester.pumpAndSettle();

    expect(c.read(appStyleChoiceProvider), kRandomStyle);
    expect(c.read(appStyleProvider), isNot(before), reason: 'something new at once');
    expect(calls.style.where((c) => c.startsWith('setIcon')), isEmpty);
    expect(calls.style.where((c) => c.startsWith('setSplash')), hasLength(1));
    // Settings names the choice, not the style it happened to draw
    expect(find.text(zh.styleRandom), findsWidgets);
  });

  for (final style in AppStyle.values) {
    testWidgets('${style.name} draws every tab and the task sheet', (tester) async {
      final c = await pumpApp(tester);
      await c.read(appStyleProvider.notifier).set(style);
      await tester.pumpAndSettle();

      for (final tab in [zh.targets, zh.goals, zh.me, zh.tasks]) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip(zh.addTask));
      await tester.pumpAndSettle();
      expect(find.text(zh.addTask), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
