import 'dart:developer' as developer;
import 'dart:ui';
import 'package:family_budget/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/local_db_service.dart';
import 'services/pending_deletions_store.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';

/// Точка входа в приложение.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    developer.log(
      '❌ [UI Error]',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      '❌ [Async Error]',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await LocalDbService.init();
  await PendingDeletionsStore.init();
  await ApiService.instance.init();

  runApp(const FinanceApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Family Budget',
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const MainShell(),
        '/login': (context) => const AuthScreen(),
      },
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
    );
  }
}
