import 'dart:convert';
import 'package:http/http.dart' as http;

class LabRequestService {
  final String baseUrl = "http://127.0.0.1:5000"; // Adjust the URL if needed

  Future<List<dynamic>> fetchLabRequests({
    required String mrCode,
    required String visitDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/lab_request_records?mr_code=$mrCode&visit_date=$visitDate"),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body); // Assuming the response body is a list of records
      } else {
        throw Exception("Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }
}
