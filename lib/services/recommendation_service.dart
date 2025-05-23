import 'dart:convert';
import 'package:http/http.dart' as http;

class RecommendationService {
  final String baseUrl = "http://127.0.0.1:5000"; // adjust if needed

  Future<List<dynamic>> fetchRecommendations({
    required String mrCode,
    required String visitDate,
    required Map<String, dynamic> user,
  }) async {
    final uri = Uri.parse("$baseUrl/recommend");
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "mr_code": mrCode,
        "visit_date": visitDate,
        "user": user,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> decoded = json.decode(response.body) as List<dynamic>;

   // debug
      return decoded;
    } else {
      throw Exception("Failed (${response.statusCode}): ${response.body}");
    }
  }
}
