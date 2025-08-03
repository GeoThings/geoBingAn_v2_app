import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl => 
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';
  
  static String get geminiApiKey => 
      dotenv.env['GEMINI_API_KEY'] ?? '';
  
  static String get googleMapsApiKey => 
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  
  static const String appName = 'geoBingAn';
  static const String appVersion = '1.0.0';
  
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration tokenRefreshBuffer = Duration(minutes: 5);
  
  static const List<String> supportedLanguages = ['en', 'zh-hant', 'zh-hans'];
  static const String defaultLanguage = 'zh-hant';
  
  static const int maxChatHistoryLength = 100;
  static const int maxFileUploadSize = 10 * 1024 * 1024; // 10MB
}