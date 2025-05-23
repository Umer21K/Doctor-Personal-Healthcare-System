import 'dart:convert';
import 'package:http/http.dart' as http;

class LabResultService {
  final String baseUrl = "http://127.0.0.1:5000";  // Update if the backend URL changes

  Future<List<dynamic>> fetchLabResults({
    required String mrCode,
    required String visitDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/lab_result_records?mr_code=$mrCode&visit_date=$visitDate"),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      } else {
        throw Exception("Error fetching lab results: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }
}
