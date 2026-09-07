import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/local_db_service.dart';
import 'screens/main_shell.dart';

/// Точка входа. Порядок важен:
/// 1) читаем `.env` (адрес бэкенда и т.п. — см. ApiConfig), отсутствие файла
///    не критично, тогда действуют значения по умолчанию;
/// 2) поднимаем локальную БД (ObjectBox) — без неё экраны не смогут
///    прочитать/сохранить транзакции и бюджеты;
/// 3) запускаем виджет-дерево приложения.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env не создан (например, свежий чекаут без `cp .env.example .env') —
    // приложение продолжает работать на значениях по умолчанию.
  }

  await LocalDbService.init();
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
