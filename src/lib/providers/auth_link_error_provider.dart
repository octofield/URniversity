import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Why an auth link failed, in terms the user can act on
enum AuthLinkFailure {
  // The token was already used, or more than an hour old. Only the newest
  // reset email works: Supabase keeps one recovery_token per user and a new
  // request overwrites the previous one
  expired,
  // PKCE stores the code verifier on the device that pressed "forgot
  // password", so the link has to be opened there
  wrongDevice,
}

// A bad auth link reaches the app through two different paths, and neither one
// surfaces on its own:
//
//   1. The verify endpoint redirects with ?error=...&error_code=otp_expired in
//      the QUERY string. supabase_flutter's _isAuthCallbackDeeplink
//      (supabase_auth.dart:183) only looks for error_description in the
//      FRAGMENT, so it never treats that URL as a callback and
//      getSessionFromUrl is never called — nothing is thrown, nothing is logged
//   2. A PKCE exchange that fails does throw, and notifyException puts it on
//      onAuthStateChange — but supabase_flutter subscribes with an empty
//      onError (supabase_auth.dart:89) so it dies there unless we look
//
// Both end up in this provider so the UI has one thing to watch.
// Always starts null and is filled in by authLinkWatcherProvider, so the UI
// sees a null -> failure transition it can listen for. WidgetRef.listen has no
// fireImmediately (flutter_riverpod consumer.dart:604), so a provider that
// started out non-null would never reach the listener
final authLinkErrorProvider = StateProvider<AuthLinkFailure?>((ref) => null);

// Supabase puts these parameters in the query on a server-side redirect and in
// the fragment on an implicit-flow callback, so both are checked
AuthLinkFailure? authLinkFailureFromUri(Uri uri) {
  final params = {
    ...uri.queryParameters,
    if (uri.fragment.isNotEmpty) ...Uri.splitQueryString(uri.fragment),
  };
  if (params['error_description'] == null && params['error'] == null) {
    return null;
  }
  // Every error Supabase can put in a redirect at this point means the same
  // thing to the user: this link no longer works, ask for a new one
  return AuthLinkFailure.expired;
}

// Only link failures belong here. Sign-in errors are thrown back to the caller
// and the login screen already shows those itself, so classifying every auth
// error would report them twice
AuthLinkFailure? authLinkFailureFromError(Object error) {
  if (error is AuthPKCEGrantCodeExchangeError) return AuthLinkFailure.wrongDevice;
  if (error is! AuthException) return null;
  const linkCodes = {'otp_expired', 'access_denied', 'validation_failed'};
  if (linkCodes.contains(error.code) || linkCodes.contains(error.statusCode)) {
    return AuthLinkFailure.expired;
  }
  return null;
}

// Feeds authLinkErrorProvider from whichever source this platform has.
//
// On web that is the launch URL. On mobile it is the deep link stream, which
// has to be watched separately because supabase_flutter drops a link carrying
// only an error — without this the app just opens and appears to do nothing,
// worse than web, where at least the address bar shows what happened
final authLinkWatcherProvider = Provider<void>((ref) {
  void report(AuthLinkFailure? failure) {
    if (failure == null) return;
    // Writing during the provider's own build is not allowed
    Future.microtask(
      () => ref.read(authLinkErrorProvider.notifier).state = failure,
    );
  }

  if (kIsWeb) {
    report(authLinkFailureFromUri(Uri.base));
    return;
  }

  final sub = AppLinks().uriLinkStream.listen(
    (uri) => report(authLinkFailureFromUri(uri)),
    // No platform channel under flutter test, and no deep links to observe
    // there either. Not a swallowed write — there is nothing to report
    onError: (Object _) {},
  );
  ref.onDispose(sub.cancel);
});
