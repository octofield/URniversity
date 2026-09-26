import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_styles.dart';
import '../services/style_channel.dart';

// The look the user picked (system_design.md §3-R). Two things, kept apart:
//
//  - the choice: one of the styles, or "random" (appStyleChoiceProvider). This
//    is what is stored (app_style, D26) and synced (user_settings.app_style)
//  - the style in use now (appStyleProvider). For a fixed choice the same
//    thing; for random, drawn once per cold start and never the same twice in
//    a row
const kRandomStyle = 'random';

// Pure, so the draw is tested without a device: any style but [except]
AppStyle pickStyle(Random rng, {AppStyle? except}) {
  final pool = AppStyle.values.where((s) => s != except).toList();
  return pool[rng.nextInt(pool.length)];
}

AppStyle? _styleNamed(String? name) => AppStyle.values.where((s) => s.name == name).firstOrNull;

// A random launch: wear the style drawn last time as "next" — Android 13+
// already showed its splash — unless it is missing or would repeat the last
// one; then draw the one after, for the splash of the launch after this
({AppStyle now, AppStyle next}) resolveRandomLaunch({
  required String? next,
  required String? last,
  required Random rng,
}) {
  final lastStyle = _styleNamed(last);
  final planned = _styleNamed(next);
  final now = planned != null && planned != lastStyle ? planned : pickStyle(rng, except: lastStyle);
  return (now: now, next: pickStyle(rng, except: now));
}

String _initialChoice = AppStyle.linen.name;
AppStyle _initialStyle = AppStyle.linen;

// The style this launch opens in, once preloadAppStyle() has run
AppStyle get launchStyle => _initialStyle;

// Read before runApp, so even the wait screen wears the style, and a random
// launch is decided exactly once — not again when the app returns from the
// background
Future<void> preloadAppStyle({Random? rng}) async {
  final p = await SharedPreferences.getInstance();
  final choice = p.getString(AppStyleNotifier.key);
  if (choice == kRandomStyle) {
    final launch = resolveRandomLaunch(
      next: p.getString(AppStyleNotifier.nextKey),
      last: p.getString(AppStyleNotifier.lastKey),
      rng: rng ?? Random(),
    );
    _initialChoice = kRandomStyle;
    _initialStyle = launch.now;
    await p.setString(AppStyleNotifier.lastKey, launch.now.name);
    await p.setString(AppStyleNotifier.nextKey, launch.next.name);
    unawaited(StyleChannel.setSplash(launch.next));
  } else {
    _initialStyle = appStyleFromName(choice);
    _initialChoice = _initialStyle.name;
  }
}

final appStyleChoiceProvider = StateProvider<String>((ref) => _initialChoice);

class AppStyleNotifier extends StateNotifier<AppStyle> {
  static const key = 'app_style';
  // Random mode's memory: the style worn last, and the one already drawn for
  // the next launch (whose splash Android 13+ has been told about)
  static const lastKey = 'app_style_last';
  static const nextKey = 'app_style_next';

  AppStyleNotifier(this._ref) : super(_initialStyle);

  final Ref _ref;

  String get choice => _ref.read(appStyleChoiceProvider);

  // A style picked by hand: worn now, and the icon and splash follow it
  Future<void> set(AppStyle style) async {
    if (state == style && choice == style.name) return;
    _ref.read(appStyleChoiceProvider.notifier).state = style.name;
    state = style;
    unawaited(StyleChannel.setIcon(style));
    unawaited(StyleChannel.setSplash(style));
    final p = await SharedPreferences.getInstance();
    await p.setString(key, style.name);
  }

  // Random: something different straight away, so picking it visibly does
  // something. The icon stays as it is
  Future<void> setRandom({Random? rng}) async {
    rng ??= Random();
    final now = pickStyle(rng, except: state);
    final next = pickStyle(rng, except: now);
    _ref.read(appStyleChoiceProvider.notifier).state = kRandomStyle;
    state = now;
    unawaited(StyleChannel.setSplash(next));
    final p = await SharedPreferences.getInstance();
    await p.setString(key, kRandomStyle);
    await p.setString(lastKey, now.name);
    await p.setString(nextKey, next.name);
  }

  // A choice made on another device, read at sign-in
  Future<void> applyChoice(String name) async {
    if (name == choice) return;
    if (name == kRandomStyle) {
      await setRandom();
    } else {
      await set(appStyleFromName(name));
    }
  }
}

final appStyleProvider =
    StateNotifierProvider<AppStyleNotifier, AppStyle>((ref) => AppStyleNotifier(ref));
