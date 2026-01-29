import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mocc/auth/auth_controller.dart';
import 'http_client_factory.dart';
import 'runtime_config.dart';

final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final authController = ref.watch(authControllerProvider);

  final apiUrl = getApiUrl();
  debugPrint('[DEVLOG] GraphQLConfig: Using API URL: $apiUrl');

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

  final Link logoutLink = Link.function((request, [forward]) async* {
    try {
      await for (final response in forward!(request)) {
        yield response;
      }
    } catch (e) {
      bool isUnauthorized = false;

      if (e is HttpLinkServerException && e.response.statusCode == 401) {
        isUnauthorized = true;
      } else if (e.toString().contains("Unauthorized APIM")) {
        isUnauthorized = true;
      }

      if (isUnauthorized) {
        debugPrint('[LogoutLink] Detected Unauthorized (401). Logging out...');
        // Trigger logout asynchronously
        Future.microtask(() => authController.signOut());
      }
      rethrow;
    }
  });

  // Retry logic should be first to handle auth errors and timeouts
  final Link link = RetryLink()
      .concat(authLink)
      .concat(logoutLink)
      .concat(httpLink);

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

  RetryLink({this.maxRetries = 10, this.delay = const Duration(seconds: 2)});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    int attempts = 0;
    while (true) {
      try {
        await for (final response in forward!(request)) {
          final status = response.context
              .entry<HttpLinkResponseContext>()
              ?.statusCode;

          // Retry on server errors (502, 503, 504) often seen during cold starts
          if (status != null &&
              (status == 502 || status == 503 || status == 504) &&
              attempts < maxRetries) {
            throw _RetryException('Server Error $status');
          }

          yield response;
        }
        return;
      } catch (e) {
        if (attempts < maxRetries && _isRecoverable(e)) {
          attempts++;
          debugPrint(
            '[RetryLink] Retrying request (attempt $attempts) due to error: $e',
          );
          await Future.delayed(delay * attempts);
          continue;
        }
        rethrow;
      }
    }
  }

  bool _isRecoverable(dynamic error) {
    if (error is _RetryException) return true;

    // Convert to lowercase string for robust checking
    final eStr = error.toString().toLowerCase();

    // Catch timeouts (common during cold start "void")
    if (error is TimeoutException || eStr.contains('timeout')) return true;

    // Catch SocketExceptions (network unreachable, DNS failure)
    if (error is SocketException || eStr.contains('socketexception'))
      return true;
    if (eStr.contains('connection refused')) return true;
    if (eStr.contains('connection closed')) return true;
    if (eStr.contains('network is unreachable')) return true;

    // Catch MSAL / Auth related network errors
    if (eStr.contains('msalclientexception') &&
        (eStr.contains('io_error') ||
            eStr.contains('unable to resolve host'))) {
      return true;
    }

    // Wrapped LinkExceptions
    if (error is LinkException) {
      if (error.originalException is SocketException ||
          error.originalException is TimeoutException) {
        return true;
      }
    }

    // Sometimes wrapped in ClientException
    if (eStr.contains('failed host lookup')) return true;

    return false;
  }
}

class _RetryException implements Exception {
  final String message;
  _RetryException(this.message);
  @override
  String toString() => message;
}
