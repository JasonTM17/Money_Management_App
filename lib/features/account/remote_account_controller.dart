import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/remote_session_store.dart';
import '../../core/remote_sync_client.dart';
import '../../core/sync_models.dart';

const _developmentApiBaseUrl = 'http://localhost:3000';

final remoteSyncClientProvider = Provider<RemoteSyncClient>(
  (ref) => RemoteSyncClient(baseUri: configuredRemoteSyncBaseUri()),
);

final remoteSessionStoreProvider = Provider<RemoteSessionStore>(
  (ref) => RemoteSessionStore(storage: ref.read(secureStorageProvider)),
);

final remoteAccountControllerProvider =
    AsyncNotifierProvider<RemoteAccountController, RemoteAccountState>(
      RemoteAccountController.new,
    );

class RemoteSyncConfigurationException implements Exception {
  const RemoteSyncConfigurationException(this.messageKey);

  final String messageKey;

  @override
  String toString() => 'RemoteSyncConfigurationException($messageKey)';
}

Uri configuredRemoteSyncBaseUri() => resolveRemoteSyncBaseUri(
  releaseMode: const bool.fromEnvironment('dart.vm.product'),
  syncEnabled: const bool.fromEnvironment('CASHFLOW_SYNC_ENABLED'),
  configuredBaseUrl: const String.fromEnvironment('CASHFLOW_API_BASE_URL'),
);

Uri resolveRemoteSyncBaseUri({
  required bool releaseMode,
  required bool syncEnabled,
  required String configuredBaseUrl,
}) {
  final trimmedBaseUrl = configuredBaseUrl.trim();
  if (releaseMode) {
    if (!syncEnabled || trimmedBaseUrl.isEmpty) {
      throw const RemoteSyncConfigurationException('syncReleaseDisabled');
    }
    final uri = _parseBaseUri(trimmedBaseUrl);
    if (uri.scheme != 'https') {
      throw const RemoteSyncConfigurationException('syncHttpsRequired');
    }
    return uri;
  }
  return _parseBaseUri(
    trimmedBaseUrl.isEmpty ? _developmentApiBaseUrl : trimmedBaseUrl,
  );
}

Uri _parseBaseUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw const RemoteSyncConfigurationException('syncInvalidBaseUrl');
  }
  return uri;
}

class RemoteAccountState {
  const RemoteAccountState({
    this.session,
    this.premium = false,
    this.lockedFeatures = const [],
    this.lastSyncAt,
    this.messageKey,
    this.syncAvailable = true,
  });

  final RemoteSession? session;
  final bool premium;
  final List<String> lockedFeatures;
  final DateTime? lastSyncAt;
  final String? messageKey;
  final bool syncAvailable;

  bool get isSignedIn => session != null;

  RemoteAccountState copyWith({
    RemoteSession? session,
    bool clearSession = false,
    bool? premium,
    List<String>? lockedFeatures,
    DateTime? lastSyncAt,
    String? messageKey,
    bool? syncAvailable,
  }) {
    return RemoteAccountState(
      session: clearSession ? null : session ?? this.session,
      premium: premium ?? this.premium,
      lockedFeatures: lockedFeatures ?? this.lockedFeatures,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      messageKey: messageKey,
      syncAvailable: syncAvailable ?? this.syncAvailable,
    );
  }
}

class RemoteAccountController extends AsyncNotifier<RemoteAccountState> {
  late final RemoteSessionStore _store = ref.read(remoteSessionStoreProvider);
  late final RemoteSyncClient _client = ref.read(remoteSyncClientProvider);

  @override
  Future<RemoteAccountState> build() async {
    try {
      configuredRemoteSyncBaseUri();
      return RemoteAccountState(session: await _store.read());
    } on RemoteSyncConfigurationException catch (error) {
      return RemoteAccountState(
        messageKey: error.messageKey,
        syncAvailable: false,
      );
    } on Object {
      return const RemoteAccountState(messageKey: 'syncSessionUnavailable');
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _authenticate(
      () => _client.login(email: email.trim(), password: password),
    );
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _authenticate(
      () => _client.register(email: email.trim(), password: password),
    );
  }

  Future<void> refreshEntitlements() async {
    final current = state.asData?.value;
    final session = current?.session;
    if (session == null) return;
    state = const AsyncLoading();
    try {
      final activeSession = session.isExpired
          ? RemoteSession.fromAuth(
              await _client.refresh(refreshToken: session.refreshToken),
            )
          : session;
      if (!identical(activeSession, session)) {
        await _store.save(activeSession);
      }
      final entitlements = await _client.fetchEntitlements(
        accessToken: activeSession.accessToken,
      );
      state = AsyncData(
        (current ?? RemoteAccountState(session: activeSession)).copyWith(
          session: activeSession,
          premium: entitlements.premium,
          lockedFeatures: entitlements.lockedFeatures,
          lastSyncAt: DateTime.now(),
          messageKey: 'syncStatusSynced',
        ),
      );
    } on RemoteSyncConfigurationException catch (error) {
      state = AsyncData(
        (current ?? RemoteAccountState(session: session)).copyWith(
          messageKey: error.messageKey,
          syncAvailable: false,
        ),
      );
    } on Object {
      state = AsyncData(
        (current ?? RemoteAccountState(session: session)).copyWith(
          messageKey: 'syncServerUnavailable',
        ),
      );
    }
  }

  Future<void> logout() async {
    final current = state.asData?.value;
    final session = current?.session;
    state = const AsyncLoading();
    try {
      if (session != null) {
        await _client.logout(refreshToken: session.refreshToken);
      }
    } on Object {
      // Offline logout still clears local tokens so the device is signed out.
    }
    await _store.clear();
    state = AsyncData(
      RemoteAccountState(syncAvailable: current?.syncAvailable ?? true),
    );
  }

  Future<void> _authenticate(
    Future<RemoteAuthSession> Function() requestSession,
  ) async {
    state = const AsyncLoading();
    try {
      final remoteSession = RemoteSession.fromAuth(await requestSession());
      await _store.save(remoteSession);
      state = AsyncData(
        RemoteAccountState(
          session: remoteSession,
          messageKey: 'syncStatusSynced',
        ),
      );
    } on RemoteSyncConfigurationException catch (error) {
      state = AsyncData(
        RemoteAccountState(messageKey: error.messageKey, syncAvailable: false),
      );
    } on Object {
      state = const AsyncData(RemoteAccountState(messageKey: 'syncAuthFailed'));
    }
  }
}
