// Invite codes for adding a friend (system_design.md §3-V). A code is eight
// characters from an alphabet without 0, O, 1 and I, so one read off a screen
// or aloud cannot be mistyped; supabase/friends.sql makes them and checks the
// same pattern

const kFriendCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const kFriendCodeLength = 8;

// The address an invite is shared as; opening it shows the invite page, in the
// app when it is installed (Android App Link) and on the web otherwise
const kInviteBase = 'https://urniversity.netlify.app/invite/';

String inviteLink(String code) => '$kInviteBase$code';

// What the user typed or pasted, as a code: upper case, spaces and dashes gone.
// A pasted message holding an invite link gives the code from the link
String normalizeFriendCode(String input) {
  final link = RegExp(r'/invite/([A-Za-z0-9-]+)').firstMatch(input);
  final raw = link?.group(1) ?? input;
  return raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}

bool isValidFriendCode(String code) =>
    code.length == kFriendCodeLength && code.split('').every(kFriendCodeAlphabet.contains);

// "ABCD 2345": easier to read out than eight in a row
String groupedFriendCode(String code) =>
    code.length == kFriendCodeLength ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
