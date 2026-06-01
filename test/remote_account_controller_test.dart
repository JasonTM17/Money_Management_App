import 'package:cashflow_manager/core/remote_sync_client.dart';
import 'package:cashflow_manager/core/sync_models.dart';
import 'package:cashflow_manager/features/account/remote_account_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'login stores session and logout clears local tokens offline-safe',
    () async {
      final client = _FakeRemoteSyncClient();
      final container = ProviderContainer(
        overrides: [remoteSyncClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(remoteAccountControllerProvider.future),
        isA<RemoteAccountState>(),
      );

      await container
          .read(remoteAccountControllerProvider.notifier)
          .login(email: 'demo@cashflow.local', password: 'Passw0rd!local');

      final signedIn = container
          .read(remoteAccountControllerProvider)
          .asData
          ?.value;
      expect(signedIn?.session?.email, 'demo@cashflow.local');

      await container.read(remoteAccountControllerProvider.notifier).logout();

      final signedOut = container
          .read(remoteAccountControllerProvider)
          .asData
          ?.value;
      expect(signedOut?.session, isNull);
      expect(client.logoutCalls, 1);
    },
  );

  test(
    'refreshEntitlements updates premium state without finance controller',
    () async {
      final client = _FakeRemoteSyncClient();
      final container = ProviderContainer(
        overrides: [remoteSyncClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      await container.read(remoteAccountControllerProvider.future);
      await container
          .read(remoteAccountControllerProvider.notifier)
          .register(email: 'demo@cashflow.local', password: 'Passw0rd!local');

      await container
          .read(remoteAccountControllerProvider.notifier)
          .refreshEntitlements();

      final state = container
          .read(remoteAccountControllerProvider)
          .asData
          ?.value;
      expect(state?.premium, isTrue);
      expect(state?.lockedFeatures, isEmpty);
      expect(state?.lastSyncAt, isNotNull);
    },
  );
}

class _FakeRemoteSyncClient extends RemoteSyncClient {
  _FakeRemoteSyncClient() : super(baseUri: Uri.parse('http://localhost'));

  int logoutCalls = 0;

  @override
  Future<RemoteAuthSession> login({
    required String email,
    required String password,
  }) async {
    return _session(email);
  }

  @override
  Future<RemoteAuthSession> register({
    required String email,
    required String password,
  }) async {
    return _session(email);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    logoutCalls += 1;
  }

  @override
  Future<RemoteEntitlementState> fetchEntitlements({
    required String accessToken,
  }) async {
    return const RemoteEntitlementState(premium: true, lockedFeatures: []);
  }

  RemoteAuthSession _session(String email) {
    return RemoteAuthSession(
      user: RemoteUser(id: 'user-1', email: email),
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }
}
