import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'timeout_http_client.dart';

http.Client createHttpClientImpl(Duration connectTimeout, Duration requestTimeout) {
  final ioClient = IOClient(HttpClient()..connectionTimeout = connectTimeout);
  return TimeoutHttpClient(ioClient, requestTimeout);
}
