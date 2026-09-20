import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/screens/auth/auth_layout.dart';
import 'package:urniversity/screens/auth/login_screen.dart';
import 'package:urniversity/screens/auth/register_screen.dart';

import '../helpers/pump_app.dart';

// The sign-in and register pages share one shell (design A, 2026-09-23): a
// brand area with the form on a card over it.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  testWidgets('the sign-in page keeps every way in', (tester) async {
    await pumpScreen(tester, const LoginScreen());

    expect(find.byType(AppMark), findsOneWidget);
    expect(find.text(zh.appTagline), findsOneWidget);
    expect(find.text(zh.emailLabel), findsOneWidget);
    expect(find.text(zh.passwordLabel), findsOneWidget);
    expect(find.text(zh.forgotPassword), findsOneWidget);
    expect(find.widgetWithText(FilledButton, zh.login), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, zh.signInWithGoogle), findsOneWidget);
    expect(find.text(zh.register), findsOneWidget);
    expect(find.text(zh.tryAsGuest), findsOneWidget);
  });

  testWidgets('the register page wears the same shell', (tester) async {
    await pumpScreen(tester, const RegisterScreen());

    expect(find.byType(AuthLayout), findsOneWidget);
    expect(find.text(zh.registerTagline), findsOneWidget);
    expect(find.text(zh.confirmPasswordLabel), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, zh.signUpWithGoogle), findsOneWidget);
    // Back to sign-in, not another way of registering
    expect(find.text(zh.haveAccountAlready), findsOneWidget);
  });

  testWidgets('a long page still scrolls on a short phone', (tester) async {
    setViewWidth(tester, 360, height: 640);
    await pumpScreen(tester, const LoginScreen(), width: 360);

    await tester.drag(find.byType(AuthLayout), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
