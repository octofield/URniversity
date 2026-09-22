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

    test('an exception with no code is not retried', () {
      expect(isTransientSyncError(const PostgrestException(message: 'x')), isFalse);
    });
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
