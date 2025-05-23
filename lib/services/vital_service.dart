import 'dart:convert';
import 'package:http/http.dart' as http;

class VitalsService {
  final String baseUrl = "http://127.0.0.1:5000"; // Adjust this URL accordingly

  Future<List<dynamic>> fetchVitals({
    required String mrCode,
    required String visitDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/vitals_records?mr_code=$mrCode&visit_date=$visitDate"),
      );

      if (response.statusCode == 200) {
        final data = List<dynamic>.from(json.decode(response.body));
        print(data);
        return List<dynamic>.from(json.decode(response.body)); // Assuming the response body is a list of records
      } else {
        throw Exception("Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }
}
