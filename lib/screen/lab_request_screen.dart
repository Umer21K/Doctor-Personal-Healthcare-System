import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/lab_request_service.dart'; // Service to handle API request

class LabRequestPage extends StatefulWidget {
  const LabRequestPage({super.key});

  @override
  State<LabRequestPage> createState() => _LabRequestPageState();
}

class _LabRequestPageState extends State<LabRequestPage> {
  final TextEditingController searchController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;
  List<dynamic> labRequestData = [];

  // Scroll controller and slider position
  final ScrollController _scrollController = ScrollController();
  double _scrollPosition = 0.0;

  // Function to fetch lab request records
  Future<void> _fetchLabRequests() async {
    final formattedVisitDate = DateFormat('MM/dd/yyyy').format(selectedDate);

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final service = LabRequestService();
      final result = await service.fetchLabRequests(
        mrCode: searchController.text.trim(),
        visitDate: formattedVisitDate,
      );

      setState(() {
        labRequestData = result;
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
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Build DataTable with horizontal scrolling and scrollbar
  Widget _buildDataTable() {
    if (labRequestData.isEmpty) {
      return const Center(child: Text('No Data Available'));
    }
    if (labRequestData.first is String) {
      return Center(child: Text(labRequestData.first));
    }

    final columns = (labRequestData.first as Map<String, dynamic>).keys.toList();

    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      child: DataTable(
        columns: columns.map((key) {
          return DataColumn(
            label: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
        rows: labRequestData.map((item) {
          final rowMap = item as Map<String, dynamic>;
          return DataRow(
            cells: columns.map((key) {
              return DataCell(
                Text(rowMap[key]?.toString() ?? ''),
              );
            }).toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Request Records'),
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
              onPressed: _fetchLabRequests,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Fetch Lab Requests'),
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
