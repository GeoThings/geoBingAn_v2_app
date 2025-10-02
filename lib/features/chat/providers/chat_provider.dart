import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ai_analysis_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/role_service.dart';

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
  final AIAnalysisService _aiAnalysisService = AIAnalysisService.instance;
  final ApiService _apiService = ApiService.instance;
  final LanguageService _languageService = LanguageService.instance;
  final RoleService _roleService = RoleService.instance;

  ChatNotifier() : super(ChatState());
  
  void startNewConversation() {
    // 清除對話狀態 (不再需要 Gemini service)
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
      // 使用新的輕量化 AI 分析服務
      final conversationHistory = _getConversationHistory();
      final result = await _aiAnalysisService.analyzeText(
        content: message,
        conversationHistory: conversationHistory,
      );

      if (result['success'] == true) {
        return result['detailed_findings'] as String? ?? result['summary'] as String? ?? '分析完成';
      } else {
        // 確保有有意義的錯誤回應
        final errorMessage = result['detailed_findings'] as String? ??
                           result['summary'] as String? ??
                           '分析服務暫時無法使用，請直接描述您的狀況，我會協助您完成報告。';
        return errorMessage;
      }
    } catch (e) {
      print('Error sending message to AI: $e');
      return '抱歉，我遇到了一些問題。請再試一次。';
    }
  }
  
  Future<String> analyzeImage(String imagePath) async {
    try {
      print('ChatProvider: Analyzing image via backend: $imagePath');

      final conversationHistory = _getConversationHistory();
      final result = await _aiAnalysisService.analyzeImage(
        imagePath: imagePath,
        conversationHistory: conversationHistory,
      );

      if (result['success'] == true) {
        return result['detailed_findings'] as String? ?? result['summary'] as String? ?? '圖片分析完成';
      } else {
        print('Backend image analysis failed: ${result['processing_info']}');
        final errorMessage = result['detailed_findings'] as String? ??
                           result['summary'] as String? ??
                           '圖片分析服務暫時無法使用，請描述圖片中的內容，我會協助您完成報告。';
        return errorMessage;
      }
    } catch (e) {
      print('Error analyzing image via backend: $e');
      return '圖片分析服務暫時無法使用。請描述圖片內容。';
    }
  }
  
  Future<String> analyzeVideo(String videoPath) async {
    try {
      print('ChatProvider: Analyzing video via backend: $videoPath');

      final conversationHistory = _getConversationHistory();
      final result = await _aiAnalysisService.analyzeVideo(
        videoPath: videoPath,
        conversationHistory: conversationHistory,
      );

      if (result['success'] == true) {
        return result['detailed_findings'] as String? ?? result['summary'] as String? ?? '影片分析完成';
      } else {
        print('Backend video analysis failed: ${result['processing_info']}');
        return result['detailed_findings'] as String? ?? '我無法分析這段影片。請描述影片內容。';
      }
    } catch (e) {
      print('Error analyzing video via backend: $e');
      return '影片分析服務暫時無法使用。請描述影片內容。';
    }
  }
  
  Future<String> transcribeAudio(String audioPath) async {
    try {
      print('ChatProvider: Processing audio via backend: $audioPath');

      final conversationHistory = _getConversationHistory();
      final result = await _aiAnalysisService.analyzeAudio(
        audioPath: audioPath,
        conversationHistory: conversationHistory,
      );

      if (result['success'] == true) {
        return result['detailed_findings'] as String? ?? result['summary'] as String? ?? '音訊分析完成';
      } else {
        print('Backend audio analysis failed: ${result['processing_info']}');
        final errorMessage = result['detailed_findings'] as String? ??
                           result['summary'] as String? ??
                           '語音分析服務暫時無法使用，請用文字描述您的狀況，我會協助您完成報告。';
        return errorMessage;
      }
    } catch (e) {
      print('Error processing audio via backend: $e');
      return '語音分析服務暫時無法使用。請用文字描述。';
    }
  }
  
  Future<Map<String, dynamic>> extractReportData() async {
    try {
      final conversationHistory = _getConversationHistory();

      final result = await _aiAnalysisService.analyzeConversation(
        messages: conversationHistory,
        extractReportData: true,
      );

      if (result['success'] == true) {
        // 回傳符合原有格式的資料
        final recommendations = result['recommendations'] as Map<String, dynamic>? ?? {};
        final riskAssessment = result['risk_assessment'] as Map<String, dynamic>? ?? {};

        return {
          'incident_type': _extractIncidentType(result),
          'location': null,  // 需要從其他地方取得
          'time': null,      // 需要從其他地方取得
          'description': result['detailed_findings'] ?? result['summary'] ?? '',
          'severity': riskAssessment['level'] ?? 'medium',
          'requires_immediate_attention': result['urgency'] == 'high' || result['urgency'] == 'critical',
          'contact_info': null,
          'additional_notes': recommendations['immediate_actions']?.join(', ') ?? '',
          'ai_analysis': result,  // 完整的 AI 分析結果
        };
      }

      return {};
    } catch (e) {
      print('Error extracting report data: $e');
      return {};
    }
  }

  Future<String> getSummary() async {
    try {
      final conversationHistory = _getConversationHistory();

      final result = await _aiAnalysisService.analyzeConversation(
        messages: conversationHistory,
        extractReportData: false,
      );

      if (result['success'] == true) {
        return result['summary'] as String? ?? '對話摘要完成';
      } else {
        return result['detailed_findings'] as String? ?? '無法生成摘要';
      }
    } catch (e) {
      print('Error getting summary: $e');
      return '無法生成對話摘要';
    }
  }

  /// 取得對話歷史 (輔助方法)
  List<String> _getConversationHistory() {
    return state.messages
        .where((m) => m is types.TextMessage)
        .map((m) => '${m.author.id}: ${(m as types.TextMessage).text}')
        .toList()
        .reversed
        .take(10) // 限制最近10則訊息
        .toList();
  }

  /// 從 AI 分析結果中萃取事件類型
  String? _extractIncidentType(Map<String, dynamic> result) {
    final riskAssessment = result['risk_assessment'] as Map<String, dynamic>? ?? {};
    final factors = riskAssessment['factors'] as List<dynamic>? ?? [];

    if (factors.isNotEmpty) {
      return factors.first.toString();
    }

    // 從詳細分析中嘗試判斷
    final findings = result['detailed_findings'] as String? ?? '';
    if (findings.contains('安全') || findings.contains('safety')) {
      return 'safety_issue';
    } else if (findings.contains('環境') || findings.contains('environment')) {
      return 'environmental_issue';
    } else if (findings.contains('結構') || findings.contains('structure')) {
      return 'structural_issue';
    }

    return null;
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