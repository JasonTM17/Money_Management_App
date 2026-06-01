import 'dart:convert';
import 'dart:io';

import 'package:cashflow_manager/core/remote_sync_client.dart';
import 'package:cashflow_manager/core/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads health and JWKS from the backend API', () async {
    final server = await _TestServer.start((request) async {
      if (request.uri.path == '/healthz') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'status': 'ok'}));
        await request.response.close();
        return;
      }
      if (request.uri.path == '/.well-known/jwks.json') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(
            jsonEncode({
              'keys': [
                {'kid': 'local-development-key'},
              ],
            }),
          );
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    try {
      final client = RemoteSyncClient(baseUri: server.baseUri);

      expect(await client.healthCheck(), isTrue);
      expect(await client.fetchJwks(), {
        'keys': [
          {'kid': 'local-development-key'},
        ],
      });
    } finally {
      await server.close();
    }
  });

  test('rejects fractional integer values in sync payload', () {
    expect(
      () => RemoteSyncBootstrap.fromJson({
        'cursor': 'cursor-1',
        'wallets': [
          {
            'id': 'cash',
            'name': 'Cash',
            'type': 'cash',
            'initialBalance': 1000.5,
          },
        ],
        'categories': <Object?>[],
        'transactions': <Object?>[],
        'budgets': <Object?>[],
        'savingGoals': <Object?>[],
      }),
      throwsFormatException,
    );
  });

  test('reads read-only sync bootstrap payload', () async {
    final server = await _TestServer.start((request) async {
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer token',
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..write(
          jsonEncode({
            'cursor': 'cursor-1',
            'wallets': [
              {
                'id': 'cash',
                'name': 'Cash',
                'type': 'cash',
                'initialBalance': 1000,
              },
            ],
            'categories': [
              {'id': 'food', 'name': 'Food', 'type': 'expense', 'colorHex': 1},
            ],
            'transactions': [
              {
                'id': 'txn-1',
                'walletId': 'cash',
                'toWalletId': null,
                'categoryId': 'food',
                'type': 'expense',
                'amount': 100,
                'date': '2026-05-30T00:00:00.000Z',
                'note': 'Lunch',
                'isRecurring': false,
              },
            ],
            'budgets': [
              {
                'id': 'budget-1',
                'categoryId': 'food',
                'month': '2026-05-01',
                'limitAmount': 2000,
              },
            ],
            'savingGoals': [
              {
                'id': 'goal-1',
                'name': 'Emergency',
                'targetAmount': 10000,
                'savedAmount': 1000,
                'deadline': '2026-12-01',
              },
            ],
          }),
        );
      await request.response.close();
    });

    try {
      final client = RemoteSyncClient(baseUri: server.baseUri);
      final payload = await client.fetchBootstrap(accessToken: 'token');

      expect(payload.cursor, 'cursor-1');
      expect(payload.wallets.single.name, 'Cash');
      expect(payload.categories.single.name, 'Food');
      expect(payload.transactions.single.amount, 100);
      expect(payload.budgets.single.limitAmount, 2000);
      expect(payload.savingGoals.single.name, 'Emergency');
    } finally {
      await server.close();
    }
  });

  test('registers, refreshes, and logs out with token DTOs', () async {
    final server = await _TestServer.start((request) async {
      final body = await utf8.decoder.bind(request).join();
      if (request.uri.path == '/v1/auth/logout') {
        expect(jsonDecode(body), {'refreshToken': 'refresh-token'});
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      expect(request.uri.path, anyOf('/v1/auth/register', '/v1/auth/refresh'));
      request.response
        ..statusCode = HttpStatus.ok
        ..write(
          jsonEncode({
            'user': {'id': 'user-1', 'email': 'demo@cashflow.local'},
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 900,
          }),
        );
      await request.response.close();
    });

    try {
      final client = RemoteSyncClient(baseUri: server.baseUri);
      final session = await client.register(
        email: 'demo@cashflow.local',
        password: 'Passw0rd!local',
      );
      final refreshed = await client.refresh(
        refreshToken: session.refreshToken,
      );
      await client.logout(refreshToken: refreshed.refreshToken);

      expect(session.user.email, 'demo@cashflow.local');
      expect(refreshed.accessToken, 'access-token');
    } finally {
      await server.close();
    }
  });

  test(
    'pulls changes, pushes mutations, and reads entitlement state',
    () async {
      final server = await _TestServer.start((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer token',
        );
        if (request.uri.path == '/v1/sync/changes') {
          expect(
            request.uri.queryParameters['since'],
            '2026-06-01T00:00:00.000Z',
          );
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'cursor': '2026-06-01T01:00:00.000Z',
                'changes': [
                  {
                    'entityType': 'wallet',
                    'entityId': 'wallet-1',
                    'operation': 'update',
                    'revision': 2,
                    'payload': {'id': 'wallet-1', 'revision': 2},
                  },
                ],
              }),
            );
          await request.response.close();
          return;
        }
        if (request.uri.path == '/v1/sync/push') {
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect((body['mutations'] as List).single['clientMutationId'], 'm-1');
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'applied': [
                  {'clientMutationId': 'm-1'},
                ],
                'conflicts': <Object?>[],
              }),
            );
          await request.response.close();
          return;
        }
        if (request.uri.path == '/v1/entitlements/me') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'premium': false,
                'entitlements': <Object?>[],
                'lockedFeatures': ['cloudSync'],
              }),
            );
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      try {
        final client = RemoteSyncClient(baseUri: server.baseUri);
        final changes = await client.fetchChanges(
          accessToken: 'token',
          since: '2026-06-01T00:00:00.000Z',
        );
        final push = await client.pushMutations(
          accessToken: 'token',
          mutations: [
            RemoteSyncMutation(
              clientMutationId: 'm-1',
              entityType: 'wallet',
              entityId: 'wallet-1',
              operation: 'update',
              baseRevision: 1,
              payload: {'name': 'Cash'},
            ),
          ],
        );
        final entitlements = await client.fetchEntitlements(
          accessToken: 'token',
        );

        expect(changes.changes.single.revision, 2);
        expect(push.applied.single['clientMutationId'], 'm-1');
        expect(entitlements.lockedFeatures, ['cloudSync']);
      } finally {
        await server.close();
      }
    },
  );
}

class _TestServer {
  const _TestServer(this._server);

  final HttpServer _server;

  Uri get baseUri => Uri.parse('http://localhost:${_server.port}');

  static Future<_TestServer> start(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handler);
    return _TestServer(server);
  }

  Future<void> close() => _server.close(force: true);
}
