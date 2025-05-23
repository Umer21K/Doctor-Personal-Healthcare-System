import 'dart:convert';
import 'package:http/http.dart' as http;

class DiagnosisService {
  final String baseUrl = "http://127.0.0.1:5000"; // Your backend server URL

  Future<List<dynamic>> fetchDiagnoses({
    required String mrCode,
    required String visitDate,
  }) async {
    try {
      // Construct the URL with query parameters
      final response = await http.get(
        Uri.parse("$baseUrl/diagnoses_records?mr_code=$mrCode&visit_date=$visitDate"), // Use the updated GET route
      );

      if (response.statusCode == 200) {
        print(List<dynamic>.from(json.decode(response.body)));
        return List<dynamic>.from(json.decode(response.body));
      } else {
        throw Exception("Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }
}
