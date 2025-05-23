import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeleteUserPage extends StatefulWidget {
  const DeleteUserPage({super.key});

  @override
  State<DeleteUserPage> createState() => _DeleteUserPageState();
}

class _DeleteUserPageState extends State<DeleteUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController userIdController = TextEditingController();
  bool isLoading = false;
  String? feedbackMessage;
  Color feedbackColor = Colors.red;

  // Function to delete user
  Future<void> _deleteUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      feedbackMessage = null;
    });

    final String userId = userIdController.text.trim();

    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:5000/delete_user'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          feedbackMessage = 'User deleted successfully';
          feedbackColor = Colors.green;
        });
      } else {
        setState(() {
          feedbackMessage = 'Failed to delete user: ${response.body}';
          feedbackColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        feedbackMessage = 'Error: $e';
        feedbackColor = Colors.red;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete User'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the ID of the user you want to remove.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),

                  // User ID Field
                  const Text('User ID', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: userIdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'User ID',
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a user ID' : null,
                  ),
                  const SizedBox(height: 24),

                  // Button & Feedback
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: isLoading ? null : _deleteUser,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('Delete User'),
                      ),
                    ],
                  ),

                  if (feedbackMessage != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      feedbackMessage!,
                      style: TextStyle(
                        color: feedbackColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}