import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/guest_provider.dart';
import 'package:urniversity/providers/password_recovery_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/screens/auth/login_screen.dart';
import 'package:urniversity/screens/auth/reset_password_screen.dart';
import 'package:urniversity/screens/home_screen.dart';

import '../helpers/pump_app.dart';

// Covers the password reset flow added in Phase 0. Retires cases 7, 8, 10, 14,
// 15 and 17 of docs/test-plans/2026-09-05-phase0-reliability.md; 9, 11, 12, 13
// and 16 still need a real inbox and a real device.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase(guest: false));

  group('login screen entry point', () {
    testWidgets('offers a forgot-password link', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      expect(find.text(zh.forgotPassword), findsOneWidget);
    });

    testWidgets('prefills the dialog with the typed email', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(find.byType(TextField).first, 'me@example.com');
      await tester.tap(find.text(zh.forgotPassword));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ));
      expect(field.controller?.text, 'me@example.com');
    });
  });

  group('new password validation', () {
    // Both checks run before the Supabase call, so nothing here reaches the
    // network even though the screen would otherwise sign the user in
    Future<void> submit(WidgetTester tester, String pw, String confirm) async {
      await pumpScreen(tester, const ResetPasswordScreen());
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), pw);
      await tester.enterText(fields.at(1), confirm);
      await tester.tap(find.text(zh.save));
      await tester.pump();
    }

    testWidgets('rejects a mismatch', (tester) async {
      await submit(tester, 'abcdef', 'abcdeg');
      expect(find.text(zh.passwordMismatch), findsOneWidget);
    });

    testWidgets('rejects fewer than six characters', (tester) async {
      await submit(tester, 'abcde', 'abcde');
      expect(find.text(zh.passwordTooShort), findsOneWidget);
    });

    testWidgets('mismatch is reported before length', (tester) async {
      await submit(tester, 'abc', 'xyz');
      expect(find.text(zh.passwordMismatch), findsOneWidget);
      expect(find.text(zh.passwordTooShort), findsNothing);
    });
  });

  group('_AuthGate routing', () {
    testWidgets('recovery beats guest mode', (tester) async {
      final c = testContainer();
      await c.read(guestModeProvider.notifier).enable();
      c.read(passwordRecoveryProvider.notifier).state = true;

      await pumpApp(tester, container: c);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('closing the screen leaves recovery mode', (tester) async {
      final c = testContainer();
      c.read(passwordRecoveryProvider.notifier).state = true;

      await pumpApp(tester, container: c);
      await tester.tap(find.byIcon(Icons.close));
      // signOut() awaits goTrue's internal lock, which only advances on the
      // real event loop; pumpAndSettle alone leaves _cancel half-finished
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(c.read(passwordRecoveryProvider), isFalse);
      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  // A hard-coded string would survive a language switch. The interface makes a
  // missing key a compile error, so this is what is left to check
  group('localized in every language', () {
    for (final lang in AppLanguage.values) {
      testWidgets(lang.name, (tester) async {
        final c = testContainer();
        c.read(languageProvider.notifier).setLanguage(lang);
        await pumpScreen(tester, const ResetPasswordScreen(), container: c);

        final s = stringsFor(lang);
        expect(find.text(s.setNewPassword), findsOneWidget);
        expect(find.text(s.newPasswordLabel), findsOneWidget);
        expect(find.text(s.confirmPasswordLabel), findsOneWidget);
        expect(find.text(s.save), findsOneWidget);
      });
    }
  });
}
