import 'dart:convert';
import 'package:http/http.dart' as http;

class RegistrationService {
  final String baseUrl = "http://127.0.0.1:5000";  // Adjust to your backend URL

  Future<List<dynamic>> fetchRegistrationRecords({
    required String mrCode,
    required String visitDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/registration_records?mr_code=$mrCode&visit_date=$visitDate"),
      );

      if (response.statusCode == 200) {

        return List<dynamic>.from(json.decode(response.body));
      } else {
        throw Exception("Error fetching registration records: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }
}
