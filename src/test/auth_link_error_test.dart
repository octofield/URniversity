import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/providers/auth_link_error_provider.dart';

// A reset link that does not work has to say so. Two separate paths produce it
// and neither surfaces on its own — see auth_link_error_provider.dart.
void main() {
  group('failure read from the callback URL', () {
    test('the query string form supabase_flutter drops', () {
      // The exact URL a dead reset link lands on. supabase_flutter's
      // _isAuthCallbackDeeplink only looks for error_description in the
      // fragment, so it never treats this as a callback at all
      final uri = Uri.parse(
        'https://urniversity.netlify.app/?error=access_denied'
        '&error_code=otp_expired'
        '&error_description=Email+link+is+invalid+or+has+expired',
      );
      expect(authLinkFailureFromUri(uri), AuthLinkFailure.expired);
    });

    test('the fragment form', () {
      final uri = Uri.parse(
        'https://urniversity.netlify.app/#error=access_denied'
        '&error_code=otp_expired&error_description=expired',
      );
      expect(authLinkFailureFromUri(uri), AuthLinkFailure.expired);
    });

    test('the android custom scheme', () {
      final uri = Uri.parse(
        'com.octofield.urniversity://login-callback'
        '?error=access_denied&error_code=otp_expired&error_description=expired',
      );
      expect(authLinkFailureFromUri(uri), AuthLinkFailure.expired);
    });

    test('a successful callback is not a failure', () {
      final uri = Uri.parse('https://urniversity.netlify.app/?code=abc123');
      expect(authLinkFailureFromUri(uri), isNull);
    });

    test('an ordinary launch URL is not a failure', () {
      expect(
        authLinkFailureFromUri(Uri.parse('https://urniversity.netlify.app/')),
        isNull,
      );
    });
  });

  group('failure read from the auth stream', () {
    test('a failed PKCE exchange means the wrong device', () {
      // Opening the link somewhere other than where the reset was requested:
      // the code verifier lives only on the requesting device
      expect(
        authLinkFailureFromError(
          AuthPKCEGrantCodeExchangeError('Code verifier could not be found'),
        ),
        AuthLinkFailure.wrongDevice,
      );
    });

    test('an expired link reported through the stream', () {
      expect(
        authLinkFailureFromError(
          const AuthException('Email link is invalid or has expired',
              code: 'otp_expired'),
        ),
        AuthLinkFailure.expired,
      );
    });

    test('a wrong password is not a link failure', () {
      // The login screen reports this one itself; classifying it here would
      // show the user two different messages for the same action
      expect(
        authLinkFailureFromError(
          const AuthException('Invalid login credentials',
              code: 'invalid_credentials'),
        ),
        isNull,
      );
    });

    test('a non-auth error is ignored', () {
      expect(authLinkFailureFromError(Exception('boom')), isNull);
    });
  });
}
