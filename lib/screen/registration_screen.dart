import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/registration_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _mrCodeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _registrationRecords = [];

  Future<void> _fetchRegistrationRecords() async {
    final formattedVisitDate = DateFormat('d/M/yyyy').format(_selectedDate);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _registrationRecords = [];
    });

    try {
      final raw = await RegistrationService().fetchRegistrationRecords(
        mrCode: _mrCodeController.text.trim(),
        visitDate: formattedVisitDate,
      );
      final mapped = raw.map<Map<String, dynamic>>((e) {
        return {
          'mr_code': e['MR_CODE'] ?? '',
          'registeredAt': e['MR_REG_DATE'] ?? e['INSERT_DT'] ?? '',
          'dob': e['MR_DOB'] ?? '',
          'sex': e['MR_SEX'] ?? '',
        };
      }).toList();

      setState(() => _registrationRecords = mapped);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildRegistrationCard(Map<String, dynamic> r) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MR Code: ${r['mr_code']}', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Registered On: ${r['registeredAt']}'),
            const SizedBox(height: 4),
            Text('DOB: ${r['dob']}'),
            const SizedBox(height: 4),
            Text('Sex: ${r['sex']}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Records'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registration Records',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lookup patient registration details by MR Code and Visit Date',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Patient Lookup',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the MR Code and Visit Date to view registration records',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mrCodeController,
                      decoration: InputDecoration(
                        labelText: 'MR Code',
                        hintText: 'Enter patient MR code',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _pickDate(context),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(
                            text: DateFormat('dd/MM/yyyy').format(_selectedDate),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Visit Date',
                            hintText: 'dd/mm/yyyy',
                            suffixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fetchRegistrationRecords,
                        child: _isLoading
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text('Search'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: _registrationRecords.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No Registration Records Found',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please search for a patient using their MR Code and Visit Date to view records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _registrationRecords.length,
                itemBuilder: (_, idx) => _buildRegistrationCard(_registrationRecords[idx]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}