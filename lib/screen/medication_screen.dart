import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../services/medication_service.dart';

class MedicationRecordsPage extends StatefulWidget {
  const MedicationRecordsPage({super.key});

  @override
  State<MedicationRecordsPage> createState() => _MedicationRecordsPageState();
}

class _MedicationRecordsPageState extends State<MedicationRecordsPage> {
  final TextEditingController searchController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;
  List<dynamic> medicationData = [];

  // Scroll controller and slider position
  final ScrollController _scrollController = ScrollController();
  double _scrollPosition = 0.0;

  // Instantiate the MedicationService
  final MedicationService _medService = MedicationService();

  // Function to fetch medication records via MedicationService
  Future<void> _fetchMedicationRecords() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final records = await _medService.fetchMedications(
        mrCode: searchController.text.trim(),
      );
      setState(() {
        medicationData =
        records.isNotEmpty ? records : ['No medication records found'];
      });
      // Reset scroll and slider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          setState(() {
            _scrollPosition = 0.0;
            _scrollController.jumpTo(0.0);
          });
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Build DataTable with horizontal scrolling, scrollbar and slider
  Widget _buildDataTable() {
    if (medicationData.isEmpty) {
      return const Center(child: Text('No Data Available'));
    }
    if (medicationData.first is String) {
      return Center(child: Text(medicationData.first));
    }

    final columns = (medicationData.first as Map<String, dynamic>).keys.toList();
    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      child: DataTable(
        columns: columns
            .map((key) => DataColumn(
          label: Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ))
            .toList(),
        rows: medicationData.map((item) {
          final rowMap = item as Map<String, dynamic>;
          return DataRow(
            cells: columns
                .map((key) => DataCell(Text(rowMap[key]?.toString() ?? '')))
                .toList(),
          );
        }).toList(),
      ),
    );

    return Column(
      children: [
        Scrollbar(
          thumbVisibility: true,
          controller: _scrollController,
          trackVisibility: true,
          child: table,
        ),
        const SizedBox(height: 8),
        Slider(
          min: 0,
          max: _scrollController.hasClients
              ? _scrollController.position.maxScrollExtent
              : 0.0,
          value: _scrollPosition.clamp(
            0.0,
            _scrollController.hasClients
                ? _scrollController.position.maxScrollExtent
                : 0.0,
          ),
          onChanged: (value) {
            setState(() {
              _scrollPosition = value;
              _scrollController.jumpTo(value);
            });
          },
        ),
      ],
    );
  }

  // Date picker function (retained, though not tied to fetch)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Records'),
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
              onPressed: _fetchMedicationRecords,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Fetch Medication Records'),
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
}
