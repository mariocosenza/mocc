import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mocc/auth/auth_controller.dart';
import 'http_client_factory.dart';
import 'runtime_config.dart';

final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final authController = ref.watch(authControllerProvider);

  final apiUrl = getApiUrl();

  final httpClient = makeHttpClient(
    connectTimeout: const Duration(minutes: 3),
    requestTimeout: const Duration(minutes: 3),
  );

  final httpLink = HttpLink(apiUrl, httpClient: httpClient);

  final authLink = AuthLink(
    getToken: () async {
      final token = await authController.token();
      return token != null ? 'Bearer $token' : null;
    },
  );

  final Link link = authLink.concat(RetryLink()).concat(httpLink);

  return GraphQLClient(link: link, cache: GraphQLCache());
});

class GraphQLConfig {
  static String get _apiUrl => getApiUrl();

  static final http.Client _httpClient = makeHttpClient(
    connectTimeout: const Duration(minutes: 3),
    requestTimeout: const Duration(minutes: 3),
  );

  static final HttpLink httpLink = HttpLink(_apiUrl, httpClient: _httpClient);

  GraphQLClient clientToQuery() =>
      GraphQLClient(link: httpLink, cache: GraphQLCache());
}

class RetryLink extends Link {
  final int maxRetries;
  final Duration delay;

  RetryLink({this.maxRetries = 3, this.delay = const Duration(seconds: 1)});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    int attempts = 0;
    while (true) {
      try {
        await for (final response in forward!(request)) {
          yield response;
        }
        return;
      } catch (e) {
        if (attempts < maxRetries && _isNetworkError(e)) {
          attempts++;
          await Future.delayed(delay * attempts);
          continue;
        }
        rethrow;
      }
    }
  }

  bool _isNetworkError(dynamic error) {
    if (error is LinkException && error.originalException is SocketException) {
      return true;
    }
    if (error is SocketException) {
      return true;
    }
    // Sometimes wrapped in ClientException
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      return true;
    }
    return false;
  }
}
