import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/local_db_service.dart';
import 'screens/main_shell.dart';

late final LocalDbService dbService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  dbService = await LocalDbService.init();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return MaterialApp(
      title: 'Family Budget',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
          secondary: const Color(0xFF14B8A6),
          surface: const Color(0xFFF8FAFC),
          error: const Color(0xFFEF4444),
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
          color: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),
      ),
      home: const MainShell(),
    );
  }
}
