import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';

// Why a sign-in attempt failed, in terms the user can act on.
//
// Supabase answers "no such account" and "wrong password" with the SAME error
// on purpose: telling them apart would let anyone use this app to find out
// whether an address is registered. So both land on [badCredentials] and the
// message names both possibilities — everything else it does distinguish gets
// its own line.
enum SignInFailure {
  badCredentials,
  emailNotConfirmed,
  tooManyTries,
  network,
  unknown,
}

SignInFailure signInFailureFrom(Object error) {
  if (error is SocketException) return SignInFailure.network;
  if (error is! AuthException) return SignInFailure.unknown;

  final code = error.code ?? error.statusCode ?? '';
  switch (code) {
    case 'invalid_credentials':
    case 'invalid_grant':
    case '400':
      return SignInFailure.badCredentials;
    case 'email_not_confirmed':
      return SignInFailure.emailNotConfirmed;
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
    case '429':
      return SignInFailure.tooManyTries;
  }

  // Older builds of the API answer without a code; the message is all there is
  final message = error.message.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return SignInFailure.badCredentials;
  }
  if (message.contains('email not confirmed')) {
    return SignInFailure.emailNotConfirmed;
  }
  if (message.contains('failed host lookup') ||
      message.contains('socketexception') ||
      message.contains('network')) {
    return SignInFailure.network;
  }
  return SignInFailure.unknown;
}

String signInFailureMessage(SignInFailure failure, AppStrings s) {
  switch (failure) {
    case SignInFailure.badCredentials:  return s.signInBadCredentials;
    case SignInFailure.emailNotConfirmed: return s.signInEmailNotConfirmed;
    case SignInFailure.tooManyTries:    return s.signInTooManyTries;
    case SignInFailure.network:         return s.signInNetwork;
    case SignInFailure.unknown:         return s.signInUnknown;
  }
}
