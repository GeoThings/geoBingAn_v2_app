import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/language_service.dart';

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
  final LanguageService _languageService = LanguageService.instance;
  
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
  
  Future<String> analyzeImage(String imagePath) async {
    try {
      print('ChatProvider: Analyzing image from path: $imagePath');
      
      final languageInstruction = _languageService.getLanguageInstruction();
      final prompt = '''You are a safety incident reporting assistant. A user has uploaded a photo for their incident report.

Look at this image and respond conversationally as if you're talking directly to the user.

Describe what you see in the photo:
- What appears to be happening or what happened
- Any visible hazards or safety concerns
- Location details if visible
- People or vehicles involved
- Any damage or injuries visible
- Time of day if determinable
- Weather conditions if relevant

After describing what you see, ask relevant follow-up questions to gather more details about the incident.

IMPORTANT: Respond in natural language as a helpful assistant, NOT in bullet points or structured format. Have a conversation with the user about what you observed.$languageInstruction''';
      
      final result = await _geminiService.analyzeImageWithText(imagePath, prompt);
      print('Image analysis result: $result');
      
      if (result['success'] == true) {
        return result['analysis'] as String;
      } else {
        final error = result['error'] ?? 'Unknown error';
        print('Image analysis failed: $error');
        return 'I was unable to analyze the image properly. Please describe what the photo shows.';
      }
    } catch (e) {
      print('Error analyzing image: $e');
      return 'I encountered an error analyzing the photo. Please describe what it shows so I can help you with your report.';
    }
  }
  
  Future<String> analyzeVideo(String videoPath) async {
    try {
      print('ChatProvider: Analyzing video from path: $videoPath');
      
      final result = await _geminiService.analyzeVideoFrame(videoPath);
      print('Video analysis result: $result');
      
      if (result['success'] == true) {
        return result['analysis'] as String;
      } else {
        final error = result['error'] ?? 'Unknown error';
        print('Video analysis failed: $error');
        return 'I had trouble processing the video. Please describe what it shows.';
      }
    } catch (e) {
      print('Error analyzing video: $e');
      return 'I had trouble processing the video. Please describe what it shows.';
    }
  }
  
  Future<String> transcribeAudio(String audioPath) async {
    try {
      print('ChatProvider: Processing audio from path: $audioPath');
      // Use Gemini Pro to process audio directly
      final response = await _geminiService.transcribeAudioWithGemini(audioPath);
      return response;
    } catch (e) {
      print('Error transcribing audio: $e');
      return _languageService.getErrorMessage();
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