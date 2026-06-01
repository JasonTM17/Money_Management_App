import 'dart:convert';
import 'dart:io';

import 'sync_models.dart';

class RemoteApiException implements Exception {
  const RemoteApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, Object?>? details;

  @override
  String toString() => 'RemoteApiException($statusCode, $code)';
}

class RemoteSyncClient {
  RemoteSyncClient({required this.baseUri, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient() {
    _guardReleaseBaseUri(baseUri);
  }

  final Uri baseUri;
  final HttpClient _httpClient;

  Future<bool> healthCheck() async {
    final response = await _get('/healthz');
    return response.statusCode == HttpStatus.ok;
  }

  Future<Map<String, Object?>> fetchJwks() async {
    final response = await _get('/.well-known/jwks.json');
    return _decodeObject(response);
  }

  Future<RemoteAuthSession> register({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/v1/auth/register',
      body: {'email': email, 'password': password},
    );
    return RemoteAuthSession.fromJson(await _decodeObject(response));
  }

  Future<RemoteAuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return RemoteAuthSession.fromJson(await _decodeObject(response));
  }

  Future<RemoteAuthSession> refresh({required String refreshToken}) async {
    final response = await _post(
      '/v1/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return RemoteAuthSession.fromJson(await _decodeObject(response));
  }

  Future<void> logout({required String refreshToken}) async {
    final response = await _post(
      '/v1/auth/logout',
      body: {'refreshToken': refreshToken},
    );
    if (response.statusCode != HttpStatus.noContent) {
      await _decodeObject(response);
    } else {
      await response.drain<void>();
    }
  }

  Future<RemoteSyncBootstrap> fetchBootstrap({
    required String accessToken,
  }) async {
    final response = await _get(
      '/v1/sync/bootstrap',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
    );
    return RemoteSyncBootstrap.fromJson(await _decodeObject(response));
  }

  Future<RemoteSyncChanges> fetchChanges({
    required String accessToken,
    String? since,
  }) async {
    final path = since == null
        ? '/v1/sync/changes'
        : '/v1/sync/changes?since=${Uri.encodeQueryComponent(since)}';
    final response = await _get(
      path,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
    );
    return RemoteSyncChanges.fromJson(await _decodeObject(response));
  }

  Future<RemoteSyncPushResponse> pushMutations({
    required String accessToken,
    required List<RemoteSyncMutation> mutations,
  }) async {
    final response = await _post(
      '/v1/sync/push',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
      body: {
        'mutations': mutations.map((mutation) => mutation.toJson()).toList(),
      },
    );
    return RemoteSyncPushResponse.fromJson(await _decodeObject(response));
  }

  Future<RemoteEntitlementState> fetchEntitlements({
    required String accessToken,
  }) async {
    final response = await _get(
      '/v1/entitlements/me',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
    );
    return RemoteEntitlementState.fromJson(await _decodeObject(response));
  }

  Future<HttpClientResponse> _get(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final request = await _httpClient.getUrl(baseUri.resolve(path));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    return request.close();
  }

  Future<HttpClientResponse> _post(
    String path, {
    required Map<String, Object?> body,
    Map<String, String> headers = const {},
  }) async {
    final request = await _httpClient.postUrl(baseUri.resolve(path));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.contentTypeHeader, 'application/json');
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.write(jsonEncode(body));
    return request.close();
  }

  Future<Map<String, Object?>> _decodeObject(
    HttpClientResponse response,
  ) async {
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _remoteApiException(response.statusCode, body);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('invalidSyncPayload');
    }
    return decoded;
  }

  RemoteApiException _remoteApiException(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final code = decoded['code'];
        final message = decoded['message'];
        final details = decoded['details'];
        return RemoteApiException(
          statusCode: statusCode,
          code: code is String ? code : 'syncHttp$statusCode',
          message: message is String ? message : 'Remote API request failed',
          details: details is Map<String, Object?> ? details : null,
        );
      }
    } on Object {
      // Fall through to stable generic error.
    }
    return RemoteApiException(
      statusCode: statusCode,
      code: 'syncHttp$statusCode',
      message: 'Remote API request failed',
    );
  }

  void _guardReleaseBaseUri(Uri uri) {
    const isProduct = bool.fromEnvironment('dart.vm.product');
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (isProduct && uri.scheme != 'https' && !isLocalhost) {
      throw ArgumentError.value(
        uri.toString(),
        'baseUri',
        'Production sync API must use HTTPS',
      );
    }
  }
}
