import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/core/sign_in_failure.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';

// "Invalid login credentials" is what Supabase says for both a wrong password
// and an address that was never registered — it will not tell them apart, so
// nor can the app. Everything it does distinguish gets its own line.
void main() {
  const zh = StringsZhTw();

  test('a wrong password and an unknown account read the same', () {
    final byCode = const AuthException('Invalid login credentials', code: 'invalid_credentials');
    final byMessage = const AuthException('Invalid login credentials');

    expect(signInFailureFrom(byCode), SignInFailure.badCredentials);
    expect(signInFailureFrom(byMessage), SignInFailure.badCredentials);
    expect(signInFailureMessage(SignInFailure.badCredentials, zh),
        zh.signInBadCredentials);
  });

  test('an unverified email says so', () {
    expect(
      signInFailureFrom(const AuthException('Email not confirmed', code: 'email_not_confirmed')),
      SignInFailure.emailNotConfirmed,
    );
    expect(
      signInFailureFrom(const AuthException('Email not confirmed')),
      SignInFailure.emailNotConfirmed,
    );
  });

  test('too many attempts says to wait', () {
    expect(
      signInFailureFrom(const AuthException('rate limited', code: 'over_request_rate_limit')),
      SignInFailure.tooManyTries,
    );
    expect(
      signInFailureFrom(const AuthException('rate limited', statusCode: '429')),
      SignInFailure.tooManyTries,
    );
  });

  test('no connection is not a password problem', () {
    expect(signInFailureFrom(const SocketException('Failed host lookup')),
        SignInFailure.network);
    expect(signInFailureFrom(const AuthException('Failed host lookup: supabase.co')),
        SignInFailure.network);
  });

  test('anything else still gets a sentence in the user language', () {
    expect(signInFailureFrom(const AuthException('weird', code: 'teapot')),
        SignInFailure.unknown);
    expect(signInFailureFrom(StateError('not an auth error')),
        SignInFailure.unknown);
    expect(signInFailureMessage(SignInFailure.unknown, zh), zh.signInUnknown);
  });
}
