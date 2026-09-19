import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Base URL API
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ??
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: "https://albirr.web.id/api",
      );

  // API Key Header
  static String get apiKey =>
      dotenv.env['API_KEY'] ??
      const String.fromEnvironment('API_KEY', defaultValue: "");

  // Header default untuk setiap request
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-API-KEY': apiKey.trim(),
  };
}