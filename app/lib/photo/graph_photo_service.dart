import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GraphService {
  Future<Uint8List?> getMyPhotoBytes(String accessToken) async {
    final res = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me/photo/\$value'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }

    // 404 means user has no photo; other codes may be permissions/consent.
    return null;
  }
}
