import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart';

String getErrorMessage(dynamic error) {
  if (error is OperationException) {
    if (error.linkException != null) {
      final linkException = error.linkException;
      if (linkException is NetworkException ||
          linkException is ServerException ||
          // Check for timeout related messages in the exception string if specific type is hard to catch
          error.toString().toLowerCase().contains('timeout') ||
          error.toString().toLowerCase().contains('socketexception')) {
        return 'server_starting_up';
      }
    }
  } else if (error.toString().toLowerCase().contains('timeout') ||
      error.toString().toLowerCase().contains('socketexception') ||
      error is ClientException) {
    /// handle http client exception
    return 'server_starting_up';
  }

  return 'something_went_wrong';
}
