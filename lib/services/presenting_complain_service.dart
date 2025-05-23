import 'dart:convert';
import 'package:http/http.dart' as http;

class PresentingComplaintService {
  final String baseUrl = "http://127.0.0.1:5000"; // Ensure your backend is running on this URL

  Future<List<dynamic>> fetchPresentingComplaint({
    required String mrCode,
    required String visitDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/presenting_complain_records?mr_code=$mrCode&visit_date=$visitDate"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {

        return List<dynamic>.from(json.decode(response.body));
      } else {
        throw Exception("Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }
}
