import 'package:flutter/material.dart';
import 'presenting_complain_page.dart';
import 'vital_screen.dart';
import 'lab_request_screen.dart';
import 'lab_result_screen.dart';
import 'medication_screen.dart';
import 'delete_user_screen.dart';
import 'recommend_screen.dart';
import 'add_user_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Map<String, dynamic> _user;
  String selectedSection = 'Welcome';

  // Controllers for the search bar
  final TextEditingController _mrCodeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // All possible sections
  final List<Map<String, dynamic>> sections = [
    {'title': 'Registration', 'icon': Icons.account_circle},
    {'title': 'Presenting Complaint', 'icon': Icons.report_problem},
    {'title': 'Patient History', 'icon': Icons.history},
    {'title': 'Diagnosis', 'icon': Icons.medical_services},
    {'title': 'Vitals', 'icon': Icons.favorite},
    {'title': 'Allergy', 'icon': Icons.warning_amber},
    {'title': 'Lab Request', 'icon': Icons.science},
    {'title': 'Lab Results', 'icon': Icons.analytics},
    {'title': 'Medications', 'icon': Icons.medication},
    {'title': 'Recommendations', 'icon': Icons.lightbulb},
    {'title': 'Add User', 'icon': Icons.person_add},
    {'title': 'Delete User', 'icon': Icons.delete},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _user = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  void _searchRecords() {
    final mrCode = _mrCodeController.text;
    final visitDate = _dateController.text;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching MR: $mrCode  Date: $visitDate'),
      ),
    );
  }

  void _navigateToSection(String section) {
    if ((_user['role'] != 'admin') && (section == 'Add User' || section == 'Delete User')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied')),
      );
      return;
    }

    switch (section) {
      case 'Registration':
        Navigator.pushNamed(context, '/registration');
        break;
      case 'Presenting Complaint':
        Navigator.pushNamed(context, '/presentingComplaint');
        break;
      case 'Patient History':
        Navigator.pushNamed(context, '/history');
        break;
      case 'Diagnosis':
        Navigator.pushNamed(context, '/diagnosis');
        break;
      case 'Vitals':
        Navigator.pushNamed(context, '/vitalsRecords');
        break;
      case 'Lab Request':
        Navigator.pushNamed(context, '/labRequest');
        break;
      case 'Lab Results':
        Navigator.pushNamed(context, '/labResults');
        break;
      case 'Medications':
        Navigator.pushNamed(context, '/medicationRecords');
        break;
      case 'Recommendations':
        Navigator.pushNamed(context, '/recommendations', arguments: _user);
        break;
      case 'Add User':
        Navigator.pushNamed(context, '/addUser');
        break;
      case 'Delete User':
        Navigator.pushNamed(context, '/deleteUser');
        break;
      default:
      // no-op
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter for non-admins
    final filteredSections = sections.where((s) {
      final title = s['title'] as String;
      if ((title == 'Add User' || title == 'Delete User') && _user['role'] != 'admin') {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Record Search'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text('Patient Sections', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ...filteredSections.map((section) {
              return ListTile(
                leading: Icon(section['icon']),
                title: Text(section['title']),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToSection(section['title']);
                },
              );
            }).toList(),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the patient MR Code and Visit Date to access records',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mrCodeController,
                    decoration: InputDecoration(
                      labelText: 'MR Code',
                      hintText: 'Enter patient MR code',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText: 'Visit Date',
                      hintText: 'dd/mm/yyyy',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _searchRecords,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: filteredSections.map((section) {
                  return GestureDetector(
                    onTap: () => _navigateToSection(section['title']),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF34C0F1), Color(0xFF8A3FFC)],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(section['icon'], size: 28, color: const Color(0xFF34C0F1)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(section['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        section['title'],
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
