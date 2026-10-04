import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/providers/synced_list_notifier.dart';

// Which failures are worth another attempt. Getting this wrong is expensive in
// both directions: retrying a schema error just delays the report, and NOT
// retrying a transient one loses the write, because the app updates local state
// optimistically and never revisits a failed push.
void main() {
  PostgrestException err(String code) =>
      PostgrestException(message: 'x', code: code);

  group('isTransientSyncError', () {
    test('PGRST303 (JWT issued at future) is transient', () {
      expect(isTransientSyncError(err('PGRST303')), isTrue);
    });

    test('PGRST301 (JWT expired) is transient', () {
      expect(isTransientSyncError(err('PGRST301')), isTrue);
    });

    test('connection failures are transient', () {
      expect(isTransientSyncError(const SocketException('offline')), isTrue);
      expect(isTransientSyncError(TimeoutException('slow')), isTrue);
      expect(isTransientSyncError(ClientException('reset')), isTrue);
    });

    test('a token refresh that failed on a sleeping network is transient', () {
      // What the first write after a long background stint throws when the
      // expired access token could not be refreshed yet
      expect(isTransientSyncError(AuthRetryableFetchException()), isTrue);
    });

    test('other auth errors are not', () {
      expect(isTransientSyncError(const AuthException('invalid refresh token')),
          isFalse);
    });

    test('schema and policy errors are not', () {
      // 23502 not-null, 23503 foreign key, 42P10 bad onConflict,
      // 42703 missing column, 42501 RLS — all fail the same way next time
      for (final code in ['23502', '23503', '42P10', '42703', '42501']) {
        expect(isTransientSyncError(err(code)), isFalse, reason: code);
      }
    });

    // What a .maybeSingle() query throws: postgrest-dart keeps only the HTTP
    // status and puts PostgREST's JSON in the message. Every "JWT issued at
    // future" of the user_settings loads looked like this (2026-09-28 to
    // 10-04) and was never retried
    test('the code inside a .maybeSingle() 401 is read back', () {
      PostgrestException wrapped(String code) => PostgrestException(
            message: '{"code":"$code","details":null,"hint":null,"message":"JWT issued at future"}',
            code: '401',
            details: 'Unauthorized',
          );
      expect(postgrestCode(wrapped('PGRST303')), 'PGRST303');
      expect(isTransientSyncError(wrapped('PGRST303')), isTrue);
      expect(isTransientSyncError(wrapped('PGRST301')), isTrue);
      expect(isTransientSyncError(wrapped('42501')), isFalse, reason: 'RLS stays a one-off');
      expect(isTransientSyncError(const PostgrestException(message: 'Unauthorized', code: '401')), isFalse,
          reason: 'no code inside: not guessed at');
    });

    test('an exception with no code is not retried', () {
      expect(isTransientSyncError(const PostgrestException(message: 'x')), isFalse);
    });
  });

  test('a single-row read retries like a write and returns the row', () async {
    var calls = 0;
    final row = await readWithRetry(() async {
      calls++;
      if (calls < 2) {
        throw const PostgrestException(message: '{"code":"PGRST303","message":"JWT issued at future"}', code: '401');
      }
      return {'language': 'zh_tw'};
    });
    expect(calls, 2);
    expect(row, {'language': 'zh_tw'});
  });

  group('runWithRetry', () {
    test('returns without retrying when the write succeeds', () async {
      var calls = 0;
      await runWithRetry(() async => calls++);
      expect(calls, 1);
    });

    test('retries a transient failure and succeeds', () async {
      var calls = 0;
      await runWithRetry(() async {
        calls++;
        if (calls < 3) throw err('PGRST303');
      });
      expect(calls, 3);
    });

    test('gives up after maxAttempts and rethrows', () async {
      var calls = 0;
      await expectLater(
        runWithRetry(() async {
          calls++;
          throw err('PGRST303');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 5, reason: 'default is 5 attempts, not unbounded');
    });

    test('does not retry a schema error', () async {
      var calls = 0;
      await expectLater(
        runWithRetry(() async {
          calls++;
          throw err('23502');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1, reason: 'a not-null violation will not fix itself');
    });

    test('honours a raised maxAttempts', () async {
      var calls = 0;
      await expectLater(
        runWithRetry(() async {
          calls++;
          throw err('PGRST303');
        }, maxAttempts: 4),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 4);
    });
  });
}
