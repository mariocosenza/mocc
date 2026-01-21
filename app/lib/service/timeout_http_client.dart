import 'package:http/http.dart' as http;
import 'dart:async';

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
