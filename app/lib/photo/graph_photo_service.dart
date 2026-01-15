import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GraphService {
  Future<Map<String, dynamic>?> getMe(String accessToken) async {
    final res = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }

    // ignore: avoid_print
    print('GraphService: getMe failed. Status: ${res.statusCode}, Body: ${res.body}');
    return null;
  }

  Future<Uint8List?> getMyPhotoBytes(String accessToken) async {
    final res = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me/photo/\$value'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }

    if (res.statusCode == 404) {
      // User has no photo set, or no mailbox. This is expected for many users.
      return null;
    }

    // ignore: avoid_print
    print('GraphService: getMyPhotoBytes failed. Status: ${res.statusCode}, Body: ${res.body}');

    return null;
  }
}
