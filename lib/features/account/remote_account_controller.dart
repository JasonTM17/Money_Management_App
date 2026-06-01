import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/remote_session_store.dart';
import '../../core/remote_sync_client.dart';
import '../../core/sync_models.dart';

final remoteSyncClientProvider = Provider<RemoteSyncClient>(
  (ref) => RemoteSyncClient(
    baseUri: Uri.parse(
      const String.fromEnvironment(
        'CASHFLOW_API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
    ),
  ),
);

final remoteSessionStoreProvider = Provider<RemoteSessionStore>(
  (ref) => RemoteSessionStore(storage: ref.read(secureStorageProvider)),
);

final remoteAccountControllerProvider =
    AsyncNotifierProvider<RemoteAccountController, RemoteAccountState>(
      RemoteAccountController.new,
    );

class RemoteAccountState {
  const RemoteAccountState({
    this.session,
    this.premium = false,
    this.lockedFeatures = const [],
    this.lastSyncAt,
    this.messageKey,
  });

  final RemoteSession? session;
  final bool premium;
  final List<String> lockedFeatures;
  final DateTime? lastSyncAt;
  final String? messageKey;

  bool get isSignedIn => session != null;

  RemoteAccountState copyWith({
    RemoteSession? session,
    bool clearSession = false,
    bool? premium,
    List<String>? lockedFeatures,
    DateTime? lastSyncAt,
    String? messageKey,
  }) {
    return RemoteAccountState(
      session: clearSession ? null : session ?? this.session,
      premium: premium ?? this.premium,
      lockedFeatures: lockedFeatures ?? this.lockedFeatures,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      messageKey: messageKey,
    );
  }
}

class RemoteAccountController extends AsyncNotifier<RemoteAccountState> {
  late final RemoteSessionStore _store = ref.read(remoteSessionStoreProvider);
  late final RemoteSyncClient _client = ref.read(remoteSyncClientProvider);

  @override
  Future<RemoteAccountState> build() async {
    try {
      return RemoteAccountState(session: await _store.read());
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
      final entitlements = await _client.fetchEntitlements(
        accessToken: session.accessToken,
      );
      state = AsyncData(
        (current ?? RemoteAccountState(session: session)).copyWith(
          premium: entitlements.premium,
          lockedFeatures: entitlements.lockedFeatures,
          lastSyncAt: DateTime.now(),
          messageKey: 'syncStatusSynced',
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
    state = const AsyncData(RemoteAccountState());
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
    } on Object {
      state = const AsyncData(RemoteAccountState(messageKey: 'syncAuthFailed'));
    }
  }
}
