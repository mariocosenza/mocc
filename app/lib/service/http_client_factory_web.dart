import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'timeout_http_client.dart';

http.Client createHttpClientImpl(Duration connectTimeout, Duration requestTimeout) {
  final client = BrowserClient();
  return TimeoutHttpClient(client, requestTimeout);
}
