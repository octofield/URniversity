import 'package:flutter/material.dart';

// Motion tokens (system_design.md §3-Q). Named for what the movement is doing,
// with the values taken straight from Material 3's own tokens (Durations,
// Easing) rather than re-typed — scattered 150/220/420 ms numbers are what this
// replaces.
//
//  - enter: something arriving. Emphasized decelerate, so it lands softly
//  - exit: something leaving. Short and accelerating; nobody waits for a goodbye
//  - move: something already on screen changing place or value
class AppMotion {
  AppMotion._();

  static const quick = Durations.short4;
  static const enter = Durations.medium4;
  static const exit = Durations.short4;
  static const move = Durations.medium2;
  static const page = Durations.medium3;
  // Long enough to see the strike-through land before the row leaves
  static const hold = Duration(milliseconds: 350);

  static const enterCurve = Easing.emphasizedDecelerate;
  static const exitCurve = Easing.emphasizedAccelerate;
  static const moveCurve = Easing.standard;
}

// 0 when the system asks for no animation (Android "Remove animations", iOS
// "Reduce motion"), otherwise 1. Every hand-made duration is multiplied by it,
// so the result simply appears
double motionScale(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false ? 0 : 1;

// A duration for an implicit animation (AnimatedSize, AnimatedSwitcher and
// friends), respecting motionScale. Never exactly zero: AnimatedSize given a
// zero duration finishes inside its own layout and trips a framework assert,
// while a microsecond is just as instant to the eye and ends on the next tick
Duration scaled(BuildContext context, Duration d) =>
    motionScale(context) == 0 ? const Duration(microseconds: 1) : d;
