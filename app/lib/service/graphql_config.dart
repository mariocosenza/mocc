import 'dart:async';
import 'dart:io' show HttpClient; // OK: guarded by kIsWeb at runtime when used
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:http/io_client.dart';
import 'package:mocc/auth/auth_controller.dart';

class TimeoutHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Duration _timeout;

  TimeoutHttpClient(this._inner, this._timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

http.Client _makeHttpClient({
  required Duration connectTimeout,
  required Duration requestTimeout,
}) {
  final http.Client base =
      kIsWeb ? BrowserClient() : IOClient(HttpClient()..connectionTimeout = connectTimeout);

  // On web, BrowserClient is fine; on mobile/desktop, IOClient gives you connectTimeout.
  return TimeoutHttpClient(base, requestTimeout);
}

final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final authController = ref.watch(authControllerProvider);

  final apiUrl = const String.fromEnvironment('MOCC_API_URL');

  final httpClient = _makeHttpClient(
    connectTimeout: const Duration(seconds: 15),
    requestTimeout: const Duration(seconds: 20),
  );

  final httpLink = HttpLink(
    apiUrl,
    httpClient: httpClient,
  );

  final authLink = AuthLink(
    getToken: () async {
      final token = await authController.token();
      return token != null ? 'Bearer $token' : null;
    },
  );

  final Link link = authLink.concat(httpLink);

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );
});

class GraphQLConfig {
  static final String _apiUrl = const String.fromEnvironment('MOCC_API_URL');

  static final http.Client _httpClient = _makeHttpClient(
    connectTimeout: const Duration(seconds: 15),
    requestTimeout: const Duration(seconds: 20),
  );

  static final HttpLink httpLink = HttpLink(
    _apiUrl,
    httpClient: _httpClient,
  );

  GraphQLClient clientToQuery() => GraphQLClient(
        link: httpLink,
        cache: GraphQLCache(),
      );
}
