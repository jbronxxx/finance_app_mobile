import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  prod,
  dev,
  local,
}

class EnvironmentConfig {
  static const String _envKey = 'selected_environment';
  static Environment _current = Environment.prod;

  static Environment get current => _current;

  static Future<void> init() async {
    if (kReleaseMode) {
      _current = Environment.prod;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final envStr = prefs.getString(_envKey);
    if (envStr != null) {
      _current = Environment.values.firstWhere(
        (e) => e.name == envStr,
        orElse: () => Environment.local,
      );
    } else {
      _current = Environment.local;
    }
  }

  static Future<void> setEnvironment(Environment env) async {
    if (kReleaseMode) return; // Защита: в релизе менять нельзя
    _current = env;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_envKey, env.name);
  }

  static String get baseUrl {
    if (kReleaseMode) {
      return dotenv.env['PROD_API_BASE_URL'] ?? 'https://prod.api.com/api/v1';
    }

    switch (_current) {
      case Environment.prod:
        return dotenv.env['PROD_API_BASE_URL'] ?? 'https://prod.api.com/api/v1';
      case Environment.dev:
        return dotenv.env['DEV_API_BASE_URL'] ?? 'https://dev.api.com/api/v1';
      case Environment.local:
        return dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
    }
  }
}
