import 'dart:convert';
import 'dart:io';

import 'sync_models.dart';

class RemoteSyncClient {
  RemoteSyncClient({required this.baseUri, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

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
      throw HttpException('syncHttp${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('invalidSyncPayload');
    }
    return decoded;
  }
}
