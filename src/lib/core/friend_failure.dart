import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';

// Why a friend request or answer failed, in terms the user can act on. The
// functions in supabase/friends.sql raise their reason as the message
// ("not_found"); like sign_in_failure.dart, each gets its own line
enum FriendFailure {
  notFound,
  self,
  already,
  limit,
  notAllowed,
  network,
  unknown,
}

FriendFailure friendFailureFrom(Object error) {
  if (error is PostgrestException) {
    switch (error.message) {
      case 'not_found':
        return FriendFailure.notFound;
      case 'self':
        return FriendFailure.self;
      case 'already':
        return FriendFailure.already;
      case 'limit':
        return FriendFailure.limit;
      case 'not_allowed':
        return FriendFailure.notAllowed;
    }
    return FriendFailure.unknown;
  }
  // SocketException on a phone, ClientException on the web
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup') || text.contains('ClientException')) {
    return FriendFailure.network;
  }
  return FriendFailure.unknown;
}

String friendFailureMessage(FriendFailure failure, AppStrings s) => switch (failure) {
      FriendFailure.notFound => s.friendCodeNotFound,
      FriendFailure.self => s.friendCodeIsYours,
      FriendFailure.already => s.friendAlready,
      FriendFailure.limit => s.friendRequestLimit,
      FriendFailure.notAllowed => s.friendNotAllowed,
      FriendFailure.network => s.signInNetwork,
      FriendFailure.unknown => s.friendFailed,
    };
