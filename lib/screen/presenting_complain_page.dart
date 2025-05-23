import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/presenting_complain_service.dart';

class PresentingComplaintPage extends StatefulWidget {
  const PresentingComplaintPage({super.key});

  @override
  State<PresentingComplaintPage> createState() => _PresentingComplaintPageState();
}

class _PresentingComplaintPageState extends State<PresentingComplaintPage> {
  final TextEditingController searchController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;
  List<dynamic> complaints = [];

  // Function to fetch presenting complaints
  Future<void> _fetchComplaints() async {
    final formattedVisitDate = DateFormat('MM/dd/yyyy').format(selectedDate);

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final service = PresentingComplaintService();
      final result = await service.fetchPresentingComplaint(
        mrCode: searchController.text.trim(),
        visitDate: formattedVisitDate,
      );

      setState(() {
        complaints = result.isNotEmpty ? result : ["No complaints found"];
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Build DataTable for complaints
  Widget _buildDataTable() {
    if (complaints.isEmpty) {
      return const Text('No Data Available');
    }
    if (complaints.first is String) {
      return Text(complaints.first);
    }

    final columns = (complaints.first as Map<String, dynamic>).keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map((key) => DataColumn(
          label: Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ))
            .toList(),
        rows: complaints.map((item) {
          final rowMap = item as Map<String, dynamic>;
          return DataRow(
            cells: columns
                .map((key) => DataCell(
              Text(rowMap[key]?.toString() ?? ''),
            ))
                .toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenting Complaint Records'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Patient MR Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    DateFormat('MM/dd/yyyy').format(selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchComplaints,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Fetch Complaints'),
            ),
            const SizedBox(height: 10),
            if (errorMessage != null)
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDataTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Date picker function
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
}

