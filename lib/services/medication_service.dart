import 'dart:convert';
import 'package:http/http.dart' as http;

class MedicationService {
  /// Base URL of your Flask backend
  final String baseUrl = "http://127.0.0.1:5000";

  /// Fetches medication records for a given patient MR code.
  ///
  /// Throws an [Exception] if the HTTP call fails or returns a non-200 status code.
  Future<List<dynamic>> fetchMedications({
    required String mrCode,
  }) async {
    try {
      // Construct the GET URL with query parameters
      final uri = Uri.parse(
        "$baseUrl/medication_records?mr_code=$mrCode",
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // Decode JSON into a List<dynamic>
        final List<dynamic> data = json.decode(response.body);
        print(data);
        return data;
      } else if (response.statusCode == 404) {
        // No records found
        return [];
      } else {
        throw Exception("Error fetching medications: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Error while fetching medications: $e");
    }
  }
}
