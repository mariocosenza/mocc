import 'dart:async';
import 'dart:io';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart';

String getErrorMessage(dynamic error) {
  final eStr = error.toString().toLowerCase();

  // Helper to check for network/cold-start indicators
  bool isRecoverableNetworkError() {
    if (eStr.contains('timeout')) return true;
    if (eStr.contains('socketexception')) return true;
    if (eStr.contains('connection refused')) return true;
    if (eStr.contains('connection closed')) return true;
    if (eStr.contains('network is unreachable')) return true;
    if (eStr.contains('bad gateway')) return true; // 502
    if (eStr.contains('service unavailable')) return true; // 503
    if (eStr.contains('gateway timeout')) return true; // 504
    if (eStr.contains('msalclientexception') &&
        (eStr.contains('io_error') ||
            eStr.contains('unable to resolve host'))) {
      return true;
    }
    return false;
  }

  if (error is OperationException) {
    if (error.linkException != null) {
      final linkException = error.linkException;
      if (linkException is NetworkException ||
          linkException is ServerException ||
          isRecoverableNetworkError()) {
        return 'server_starting_up';
      }
    }
  }

  if (error is TimeoutException ||
      error is SocketException ||
      error is ClientException ||
      isRecoverableNetworkError()) {
    return 'server_starting_up';
  }

  return 'something_went_wrong';
}
