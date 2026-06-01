import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sync_models.dart';

class RemoteSession {
  const RemoteSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  factory RemoteSession.fromAuth(RemoteAuthSession session) {
    return RemoteSession(
      userId: session.user.id,
      email: session.user.email,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: session.expiresIn),
      ),
    );
  }
}

class RemoteSessionStore {
  RemoteSessionStore({required FlutterSecureStorage storage}) : this._(storage);

  const RemoteSessionStore._(this._storage);

  final FlutterSecureStorage _storage;

  static const _userIdKey = 'remote_user_id';
  static const _emailKey = 'remote_email';
  static const _accessTokenKey = 'remote_access_token';
  static const _refreshTokenKey = 'remote_refresh_token';
  static const _expiresAtKey = 'remote_access_expires_at';

  Future<RemoteSession?> read() async {
    final userId = await _storage.read(key: _userIdKey);
    final email = await _storage.read(key: _emailKey);
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final expiresAtRaw = await _storage.read(key: _expiresAtKey);
    final expiresAt = expiresAtRaw == null
        ? null
        : DateTime.tryParse(expiresAtRaw)?.toUtc();
    if (userId == null ||
        email == null ||
        accessToken == null ||
        refreshToken == null ||
        expiresAt == null) {
      return null;
    }
    return RemoteSession(
      userId: userId,
      email: email,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  Future<void> save(RemoteSession session) async {
    await _storage.write(key: _userIdKey, value: session.userId);
    await _storage.write(key: _emailKey, value: session.email);
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(
      key: _expiresAtKey,
      value: session.expiresAt.toUtc().toIso8601String(),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
