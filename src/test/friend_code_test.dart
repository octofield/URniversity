import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/core/friend_code.dart';
import 'package:urniversity/core/friend_failure.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';

// Invite codes and what a failed friend request says (system_design.md §3-V)
void main() {
  group('invite codes', () {
    test('32 characters, none of them easily mistaken for another', () {
      expect(kFriendCodeAlphabet.length, 32);
      expect(kFriendCodeAlphabet.split('').toSet().length, 32);
      for (final c in ['0', 'O', '1', 'I']) {
        expect(kFriendCodeAlphabet.contains(c), isFalse, reason: c);
      }
    });

    test('typed in any case, with spaces or a dash, or pasted as the link', () {
      expect(normalizeFriendCode('abcd-2345'), 'ABCD2345');
      expect(normalizeFriendCode(' ABCD 2345 '), 'ABCD2345');
      expect(normalizeFriendCode('https://urniversity.netlify.app/invite/abcd2345'), 'ABCD2345');
      expect(normalizeFriendCode('看看這個 https://urniversity.netlify.app/invite/ABCD2345?x=1'), 'ABCD2345');
    });

    test('valid only at eight characters of the alphabet', () {
      expect(isValidFriendCode('ABCD2345'), isTrue);
      expect(isValidFriendCode('OOOO1111'), isFalse);
      expect(isValidFriendCode('ABCD234'), isFalse);
      expect(isValidFriendCode('ABCD23456'), isFalse);
    });

    test('the link carries the code under /invite/', () {
      expect(inviteLink('ABCD2345'), 'https://urniversity.netlify.app/invite/ABCD2345');
      expect(normalizeFriendCode(inviteLink('ABCD2345')), 'ABCD2345');
    });

    test('shown in two groups of four', () {
      expect(groupedFriendCode('ABCD2345'), 'ABCD 2345');
    });
  });

  group('why a request failed', () {
    test('each code the functions raise has its own kind and words', () {
      const s = StringsZhTw();
      const codes = {
        'not_found': FriendFailure.notFound,
        'self': FriendFailure.self,
        'already': FriendFailure.already,
        'limit': FriendFailure.limit,
        'not_allowed': FriendFailure.notAllowed,
      };
      final messages = <String>{};
      codes.forEach((code, kind) {
        final failure = friendFailureFrom(PostgrestException(message: code, code: 'P0001'));
        expect(failure, kind, reason: code);
        messages.add(friendFailureMessage(failure, s));
      });
      expect(messages.length, codes.length);
    });

    test('anything else is unknown, a dropped connection is the network', () {
      expect(friendFailureFrom(const PostgrestException(message: 'boom', code: '42883')), FriendFailure.unknown);
      expect(friendFailureFrom(Exception('x')), FriendFailure.unknown);
      expect(friendFailureFrom(const _Socket()), FriendFailure.network);
      expect(friendFailureMessage(FriendFailure.network, const StringsZhTw()), isNotEmpty);
    });
  });
}

class _Socket implements Exception {
  const _Socket();
  @override
  String toString() => 'ClientException: Failed host lookup';
}
