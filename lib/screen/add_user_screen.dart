import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = 'admin';
  String selectedDepartment = 'ITU';
  bool isLoading = false;
  String? feedbackMessage;
  Color feedbackColor = Colors.red;

  // Function to add a new user
  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      feedbackMessage = null;
    });

    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/add_user'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'role': selectedRole,
          'department': selectedDepartment,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          feedbackMessage = "User added successfully!";
          feedbackColor = Colors.green;
        });
      } else {
        setState(() {
          feedbackMessage = "Failed to add user: ${response.body}";
          feedbackColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        feedbackMessage = "Error: $e";
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
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a new user account with appropriate access level',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    const Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Name',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 16),

                    // Password
                    const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) => value != null && value.length >= 6 ? null : 'At least 6 characters',
                    ),
                    const SizedBox(height: 16),

                    // Role Dropdown
                    const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      items: <String>['doctor', 'admin']
                          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedRole = val!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Department Dropdown
                    const Text('Department', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      items: <String>[
                        '19 A', 'SICU', '19 B', 'ITU', 'BURN',
                        'MEDICAL UNIT I','MEDICAL UNIT II','MEDICAL UNIT III','NICU','GASTRO'
                      ]
                          .map((dept) => DropdownMenuItem(value: dept, child: Text(dept)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedDepartment = val!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons & Feedback
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: isLoading ? null : _addUser,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Add User'),
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
      ),
    );
  }
}