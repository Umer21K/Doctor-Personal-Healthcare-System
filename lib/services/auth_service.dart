import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:5000'; // or your server IP

  static Future<Map<String, dynamic>> loginUser(String email, String password) async {
    final url = Uri.parse('$baseUrl/validate_user');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['user'] != null) {
        return data['user'];
      }
      throw Exception('Login failed: ${data['message']}');
    } else {
      throw Exception('Login failed with status ${response.statusCode}');
    }
  }
}
