import 'package:http/http.dart' as http;

http.Client createHttpClientImpl(Duration connectTimeout, Duration requestTimeout) =>
    throw UnsupportedError('No implementation for this platform.');
