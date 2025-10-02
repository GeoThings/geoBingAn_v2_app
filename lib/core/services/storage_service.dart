import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  SharedPreferences? _prefs;
  
  StorageService._();
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // User data
  Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs?.setString('user', jsonEncode(user));
  }
  
  Map<String, dynamic>? getUser() {
    final userStr = _prefs?.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }
  
  Future<void> clearUser() async {
    await _prefs?.remove('user');
  }
  
  // Group context
  Future<void> saveCurrentGroup(Map<String, dynamic> group) async {
    await _prefs?.setString('current_group', jsonEncode(group));
  }
  
  Map<String, dynamic>? getCurrentGroup() {
    final groupStr = _prefs?.getString('current_group');
    if (groupStr != null) {
      return jsonDecode(groupStr);
    }
    return null;
  }
  
  Future<void> clearCurrentGroup() async {
    await _prefs?.remove('current_group');
  }
  
  // Chat history
  Future<void> saveChatHistory(List<Map<String, dynamic>> messages) async {
    await _prefs?.setString('chat_history', jsonEncode(messages));
  }
  
  List<Map<String, dynamic>> getChatHistory() {
    final historyStr = _prefs?.getString('chat_history');
    if (historyStr != null) {
      final decoded = jsonDecode(historyStr);
      return List<Map<String, dynamic>>.from(decoded);
    }
    return [];
  }
  
  Future<void> clearChatHistory() async {
    await _prefs?.remove('chat_history');
  }
  
  // Settings
  Future<void> saveLanguage(String language) async {
    await _prefs?.setString('language', language);
  }
  
  String getLanguage() {
    return _prefs?.getString('language') ?? 'zh-hant';
  }
  
  Future<void> saveThemeMode(String mode) async {
    await _prefs?.setString('theme_mode', mode);
  }
  
  String getThemeMode() {
    return _prefs?.getString('theme_mode') ?? 'system';
  }
  
  // Notifications
  Future<void> saveNotificationSettings(Map<String, dynamic> settings) async {
    await _prefs?.setString('notification_settings', jsonEncode(settings));
  }
  
  Map<String, dynamic> getNotificationSettings() {
    final settingsStr = _prefs?.getString('notification_settings');
    if (settingsStr != null) {
      return jsonDecode(settingsStr);
    }
    return {
      'enabled': true,
      'sound': true,
      'vibration': true,
      'urgent_only': false,
    };
  }
  
  // Draft reports
  Future<void> saveDraftReport(Map<String, dynamic> draft) async {
    final drafts = getDraftReports();
    draft['timestamp'] = DateTime.now().toIso8601String();
    drafts.add(draft);
    await _prefs?.setString('draft_reports', jsonEncode(drafts));
  }
  
  List<Map<String, dynamic>> getDraftReports() {
    final draftsStr = _prefs?.getString('draft_reports');
    if (draftsStr != null) {
      final decoded = jsonDecode(draftsStr);
      return List<Map<String, dynamic>>.from(decoded);
    }
    return [];
  }
  
  Future<void> removeDraftReport(int index) async {
    final drafts = getDraftReports();
    if (index < drafts.length) {
      drafts.removeAt(index);
      await _prefs?.setString('draft_reports', jsonEncode(drafts));
    }
  }
  
  Future<void> clearDraftReports() async {
    await _prefs?.remove('draft_reports');
  }
  
  // User Role
  Future<void> setUserRole(String role) async {
    await _prefs?.setString('user_role', role);
  }
  
  String getUserRole() {
    return _prefs?.getString('user_role') ?? 'accident_operator';
  }
  
  // General
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
  
  bool get isFirstLaunch {
    return _prefs?.getBool('has_launched') != true;
  }
  
  Future<void> setHasLaunched() async {
    await _prefs?.setBool('has_launched', true);
  }
}