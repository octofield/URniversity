import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/screens/settings_screen.dart';

// Deleting an account asks for the cheapest proof the account can give: a
// password when it has one, a trip back to Google only when it has none.
void main() {
  test('an email account types its password', () {
    expect(needsGoogleReauth(['email']), isFalse);
  });

  test('a Google-only account signs in with Google again', () {
    expect(needsGoogleReauth(['google']), isTrue);
  });

  test('an email account with Google linked still types its password', () {
    expect(needsGoogleReauth(['email', 'google']), isFalse);
    expect(needsGoogleReauth(['google', 'email']), isFalse);
  });

  test('an account with neither falls back to the password field', () {
    expect(needsGoogleReauth([]), isFalse);
    expect(needsGoogleReauth(['apple']), isFalse);
  });
}
