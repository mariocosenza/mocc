import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.html) 'http_client_factory_web.dart'
    if (dart.library.io) 'http_client_factory_io.dart';

http.Client makeHttpClient({
  required Duration connectTimeout,
  required Duration requestTimeout,
}) => createHttpClientImpl(connectTimeout, requestTimeout);
