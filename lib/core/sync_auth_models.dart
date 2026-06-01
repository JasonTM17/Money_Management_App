part of 'sync_models.dart';

class RemoteAuthSession {
  const RemoteAuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final RemoteUser user;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory RemoteAuthSession.fromJson(Map<String, Object?> json) {
    return RemoteAuthSession(
      user: RemoteUser.fromJson(_object(json, 'user')),
      accessToken: _string(json, 'accessToken'),
      refreshToken: _string(json, 'refreshToken'),
      expiresIn: _int(json, 'expiresIn'),
    );
  }
}

class RemoteUser {
  const RemoteUser({required this.id, required this.email});

  final String id;
  final String email;

  factory RemoteUser.fromJson(Map<String, Object?> json) {
    return RemoteUser(id: _string(json, 'id'), email: _string(json, 'email'));
  }
}
