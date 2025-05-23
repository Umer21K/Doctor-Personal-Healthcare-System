import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/recommendation_service.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final TextEditingController _mrCodeController = TextEditingController();
  late final Map<String, dynamic> _user;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;
  String? _errorMessage;

  // these three will hold your LLM results
  final ValueNotifier<String> _diagnosesNotifier   = ValueNotifier('No Data');
  final ValueNotifier<String> _labRequestsNotifier = ValueNotifier('No Data');
  final ValueNotifier<String> _medicationsNotifier = ValueNotifier('No Data');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Expect you to push this page with:
    // Navigator.pushNamed(context, "/recommendations", arguments: userMap);
    _user = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  /// Formats the raw API field into a user friendly Markdown string.
  String _formatField(dynamic field) {
    if (field == null) return 'No Data Available';

    // If it's a List, join with Markdown bullets
    if (field is List) {
      return field.map((e) => '- ${e.toString()}').join('\n\n');
    }

    // If it's a String, return it directly (no JSON parsing)
    if (field is String) {
      return field;
    }

    // Fallback for other types (e.g., Map)
    return field.toString();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _fetchRecommendations() async {
    final visitDate = DateFormat('M/d/yyyy').format(_selectedDate);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // now you get back a List<dynamic>
      final List<dynamic> resultList = await RecommendationService()
          .fetchRecommendations(
        mrCode: _mrCodeController.text.trim(),
        visitDate: visitDate,
        user: _user,
      );

      // take the first (and only) element and cast to a map
      final Map<String, dynamic> rec = resultList.first as Map<String, dynamic>;


      _diagnosesNotifier.value   = _formatField(rec['diagnoses']);
      _labRequestsNotifier.value = _formatField(rec['lab_requests']);
      _medicationsNotifier.value = _formatField(rec['medications']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Recommendations loaded")),
      );
    } catch (e) {
      setState(() => _errorMessage = "Error: ${e.toString()}");
      print("Error fetching recommendations: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _sectionCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        // <-- swap Text for MarkdownBody
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                )),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recommendations"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // MR code + date picker
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mrCodeController,
                    decoration: const InputDecoration(
                      labelText: "Patient MR Code",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pickDate,
                  child: Text(DateFormat('MM/dd/yyyy').format(_selectedDate)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Fetch button
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchRecommendations,
              child: _isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text("Fetch Recommendations"),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 12),

            // Scrollable result cards
            Expanded(
              child: ListView(
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: _diagnosesNotifier,
                    builder: (_, val, __) => _sectionCard("Diagnoses", val),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _labRequestsNotifier,
                    builder: (_, val, __) => _sectionCard("Lab Requests", val),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _medicationsNotifier,
                    builder: (_, val, __) => _sectionCard("Medications", val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
