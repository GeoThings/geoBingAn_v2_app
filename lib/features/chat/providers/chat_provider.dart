import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/api_service.dart';

class ChatState {
  final List<types.Message> messages;
  final bool isTyping;
  final bool isLoading;
  
  ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.isLoading = false,
  });
  
  ChatState copyWith({
    List<types.Message>? messages,
    bool? isTyping,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final GeminiService _geminiService = GeminiService.instance;
  final ApiService _apiService = ApiService.instance;
  
  ChatNotifier() : super(ChatState());
  
  void startNewConversation() {
    _geminiService.startNewChat();
    state = ChatState();
  }
  
  void addMessage(types.Message message) {
    state = state.copyWith(
      messages: [message, ...state.messages],
    );
  }
  
  void setTyping(bool isTyping) {
    state = state.copyWith(isTyping: isTyping);
  }
  
  Future<String> sendMessageToAI(String message) async {
    try {
      final response = await _geminiService.sendMessage(message);
      return response;
    } catch (e) {
      return 'Sorry, I encountered an error. Please try again.';
    }
  }
  
  Future<Map<String, dynamic>> extractReportData() async {
    final textMessages = state.messages
        .where((m) => m is types.TextMessage)
        .map((m) => '${m.author.id}: ${(m as types.TextMessage).text}')
        .toList()
        .reversed
        .toList();
    
    return await _geminiService.extractReportData(textMessages);
  }
  
  Future<String> getSummary() async {
    final textMessages = state.messages
        .where((m) => m is types.TextMessage)
        .map((m) => '${m.author.id}: ${(m as types.TextMessage).text}')
        .toList()
        .reversed
        .toList();
    
    return await _geminiService.summarizeConversation(textMessages);
  }
  
  Future<bool> submitReport() async {
    try {
      state = state.copyWith(isLoading: true);
      
      final reportData = await extractReportData();
      final summary = await getSummary();
      
      final location = _parseLocation(reportData['location']);
      
      final response = await _apiService.submitReport({
        'title': reportData['incident_type'] ?? 'Incident Report',
        'content': summary,
        'report_type': 'manual_messenger',
        'event_timestamp': _parseDateTime(reportData['time']),
        'priority': _mapSeverityToPriority(reportData['severity']),
        'status': 'new',
        'location': location,
        'responses': reportData,
        'metadata': {
          'source': 'mobile_app_chat',
          'ai_extracted': true,
        },
      });
      
      state = state.copyWith(isLoading: false);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error submitting report: $e');
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
  
  Map<String, double>? _parseLocation(dynamic locationStr) {
    if (locationStr == null) return null;
    
    // TODO: Implement geocoding to convert address to coordinates
    // For now, return default location (Taipei)
    return {
      'latitude': 25.0330,
      'longitude': 121.5654,
    };
  }
  
  String _parseDateTime(dynamic timeStr) {
    if (timeStr == null) return DateTime.now().toIso8601String();
    
    // TODO: Implement proper date/time parsing
    return DateTime.now().toIso8601String();
  }
  
  String _mapSeverityToPriority(dynamic severity) {
    if (severity == null) return 'medium';
    
    switch (severity.toString().toLowerCase()) {
      case 'critical':
        return 'critical';
      case 'high':
        return 'urgent';
      case 'medium':
        return 'high';
      case 'low':
        return 'medium';
      default:
        return 'medium';
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});