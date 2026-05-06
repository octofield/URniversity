import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _seedColor = Color(0xFFD9C0A7);
const _cardRadius = 20.0;
const _inputRadius = 16.0;
const _buttonRadius = 16.0;

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
  useMaterial3: true,
  textTheme: GoogleFonts.nunitoTextTheme(),
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(_inputRadius)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_inputRadius)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_inputRadius)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    ),
  ),
);
