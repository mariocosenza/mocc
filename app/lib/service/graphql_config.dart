import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mocc/auth/auth_controller.dart';
import 'http_client_factory.dart';

final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final authController = ref.watch(authControllerProvider);

  final apiUrl = const String.fromEnvironment('MOCC_API_URL');

  final httpClient = makeHttpClient(
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

  static final http.Client _httpClient = makeHttpClient(
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

