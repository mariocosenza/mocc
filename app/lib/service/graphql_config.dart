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

  final link = buildGraphQLLink(
    apiUrl: apiUrl,
    httpClient: httpClient,
    getToken: () async {
      final token = await authController.token();
      return token != null ? 'Bearer $token' : null;
    },
    onUnauthorized: () {
      debugPrint('[LogoutLink] Detected Unauthorized (401). Logging out...');
      Future.microtask(() => authController.signOut());
    },
  );

  return GraphQLClient(link: link, cache: GraphQLCache());
});

Link buildGraphQLLink({
  required String apiUrl,
  required http.Client httpClient,
  Future<String?> Function()? getToken,
  VoidCallback? onUnauthorized,
}) {
  final httpLink = HttpLink(apiUrl, httpClient: httpClient);

  final authLink = AuthLink(getToken: getToken ?? () async => null);

  final Link logoutLink = Link.function((request, [forward]) async* {
    try {
      await for (final response in forward!(request)) {
        yield response;
      }
    } catch (e) {
      final status = _statusFromError(e);
      final isUnauthorized =
          (status == 401) || e.toString().contains('Unauthorized APIM');

      if (isUnauthorized) {
        onUnauthorized?.call();
      }
      rethrow;
    }
  });

  // LogoutLink must be first (outermost) to catch specific errors that RetryLink couldn't fix (exhausted retries).
  // RetryLink is next, so it can catch errors (like 401) and retry (triggering AuthLink again).
  // AuthLink adds the token properly for each attempt.
  return logoutLink.concat(RetryLink()).concat(authLink).concat(httpLink);
}

class GraphQLConfig {
  static String get _apiUrl => getApiUrl();

  static final http.Client _httpClient = makeHttpClient(
    connectTimeout: const Duration(minutes: 3),
    requestTimeout: const Duration(minutes: 3),
  );

  GraphQLClient client({
    Future<String?> Function()? getToken,
    VoidCallback? onUnauthorized,
  }) {
    final link = buildGraphQLLink(
      apiUrl: _apiUrl,
      httpClient: _httpClient,
      getToken: getToken,
      onUnauthorized: onUnauthorized,
    );
    return GraphQLClient(link: link, cache: GraphQLCache());
  }
}

class RetryLink extends Link {
  final int maxRetries;
  final Duration delay;

  RetryLink({this.maxRetries = 20, this.delay = const Duration(seconds: 2)});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    int attempts = 0;

    while (true) {
      try {
        await for (final response in forward!(request)) {
          // In some cases the HttpLink may yield a Response (not throw) even on non-2xx.
          final status = response.context
              .entry<HttpLinkResponseContext>()
              ?.statusCode;

          if (status != null &&
              _shouldRetryStatus(status, attempts) &&
              attempts < maxRetries) {
            throw _RetryException('HTTP $status');
          }

          yield response;
        }
        return;
      } catch (e) {
        final status = _statusFromError(e);

        if (attempts < maxRetries && _isRecoverable(e, status, attempts)) {
          attempts++;
          final errorMessage = e.toString();
          debugPrint(
            '[RetryLink] Retrying (attempt $attempts/$maxRetries) '
            'status=${status ?? "-"} type=${e.runtimeType} '
            'err=${errorMessage.length > 200 ? "${errorMessage.substring(0, 200)}..." : errorMessage}',
          );
          await Future.delayed(delay * attempts);
          continue;
        }

        rethrow;
      }
    }
  }

  bool _isRecoverable(dynamic error, int? status, int attempts) {
    // If we have an HTTP status, retry only on transient statuses.
    if (status != null) return _shouldRetryStatus(status, attempts);

    if (error is _RetryException) return true;

    final eStr = error.toString().toLowerCase();

    if (error is TimeoutException || eStr.contains('timeout')) return true;

    if (error is SocketException || eStr.contains('socketexception')) {
      return true;
    }
    if (eStr.contains('connection refused')) return true;
    if (eStr.contains('connection closed')) return true;
    if (eStr.contains('network is unreachable')) return true;
    if (eStr.contains('failed host lookup')) return true;
    if (eStr.contains('unable to resolve host')) return true;

    if (error is LinkException) {
      final orig = error.originalException;
      if (orig is SocketException || orig is TimeoutException) return true;

      // Some versions wrap HttpLinkServerException inside LinkException
      if (orig is HttpLinkServerException) {
        return _shouldRetryStatus(orig.response.statusCode, attempts);
      }
    }

    // Some versions wrap HttpLinkServerException inside ServerException
    if (error is ServerException) {
      final orig = error.originalException;
      if (orig is SocketException || orig is TimeoutException) return true;
      if (orig is HttpLinkServerException) {
        return _shouldRetryStatus(orig.response.statusCode, attempts);
      }
    }

    // Catch Parser/Format exceptions (e.g. server returning HTML instead of JSON during 503/startup)
    if (eStr.contains('httplinkparserexception') ||
        eStr.contains('responseformatexception') ||
        eStr.contains('unexpected character') ||
        eStr.contains('format exception')) {
      return true;
    }

    return false;
  }

  bool _shouldRetryStatus(int status, int attempts) {
    // Retry 401 ONCE to allow for token refresh.
    if (status == 401) {
      return attempts < 1;
    }

    // Typical cold-start / gateway transient statuses
    if (status == 502 || status == 503 || status == 504) return true;

    // Optional but often useful
    if (status == 408 || status == 429) return true;

    return false;
  }
}

int? _statusFromError(dynamic error) {
  // Direct HttpLinkServerException (most common when APIM replies 502/503/504)
  if (error is HttpLinkServerException) return error.response.statusCode;

  // Wrapped in ServerException
  if (error is ServerException) {
    final orig = error.originalException;
    if (orig is HttpLinkServerException) return orig.response.statusCode;
  }

  // Wrapped in LinkException
  if (error is LinkException) {
    final orig = error.originalException;
    if (orig is HttpLinkServerException) return orig.response.statusCode;
    if (orig is ServerException) {
      final orig2 = orig.originalException;
      if (orig2 is HttpLinkServerException) return orig2.response.statusCode;
    }
  }

  return null;
}

class _RetryException implements Exception {
  final String message;
  _RetryException(this.message);
  @override
  String toString() => message;
}
