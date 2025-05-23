import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../components/toast_util.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = await AuthService.loginUser(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        // Pass `user` on to the dashboard (or store in a provider/singleton)
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: user,
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Login Failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
            ],
          ),
        );
      }finally {
        setState(() => _isLoading = false);
      }


    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Doctor Personal Healthcare System",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Healthcare Management System",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Login",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Enter your credentials to access the system",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      hintText: "doctor@hospital.com",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter your email' : null,
                    onFieldSubmitted: (_) {
                      // move focus to password
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      hintText: "Enter your password",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter your password' : null,
                    onFieldSubmitted: (_) {
                      // when user presses “Done” / Enter
                      _handleLogin();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "For demo, use any email from: doctor@hospital.com, nurse@hospital.com, admin@hospital.com with any password",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: _handleLogin,
                      child: const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
