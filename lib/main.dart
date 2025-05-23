import 'package:flutter/material.dart';
import 'package:fyp_frontend/screen/presenting_complain_page.dart';
import 'screen/login_screen.dart';
import 'screen/dashboard_screen.dart';
import 'screen/recommend_screen.dart';
import 'screen/diagnosis_screen.dart'; // Added Diagnosis Screen Import
import 'package:google_fonts/google_fonts.dart';
import 'screen/presenting_complain_page.dart';
import 'screen/vital_screen.dart';
import 'screen/lab_request_screen.dart';
import 'screen/lab_result_screen.dart';
import 'screen/medication_screen.dart';
import 'screen/delete_user_screen.dart';
import 'screen/registration_screen.dart';
import 'screen/add_user_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Personal Healthcare System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/recommendations': (context) => const RecommendationPage(),
        '/diagnosis': (context) => const DiagnosisPage(),
        '/presentingComplaint': (context) => PresentingComplaintPage(),
        '/vitalsRecords': (context) => VitalsPage(),
        '/labRequest': (context) => LabRequestPage(),
        '/labResults': (context) => LabResultsPage(),
        '/medicationRecords': (context) => MedicationRecordsPage(),
        '/deleteUser': (context) => DeleteUserPage(),
        '/registration': (context) => const RegistrationPage(),
        '/addUser': (context) => AddUserPage(),
      },
    );
  }
}

