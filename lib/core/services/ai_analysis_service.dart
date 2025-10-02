import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';
import 'role_service.dart';
import 'language_service.dart';

class AIAnalysisService {
  static AIAnalysisService? _instance;
  static AIAnalysisService get instance => _instance ??= AIAnalysisService._();

  AIAnalysisService._();

  final ApiService _apiService = ApiService.instance;
  final RoleService _roleService = RoleService.instance;
  final LanguageService _languageService = LanguageService.instance;

  /// 分析文字內容
  Future<Map<String, dynamic>> analyzeText({
    required String content,
    List<String>? conversationHistory,
    Map<String, dynamic>? location,
  }) async {
    try {
      final currentRole = _roleService.getCurrentRole();

      final requestData = {
        'type': 'text',
        'content': content,
        'conversation_history': conversationHistory ?? [],
        'location': location != null ? jsonEncode(location) : null,
      };

      final response = await _apiService.dio.post(
        '/reports/ai-analysis-json/',
        data: requestData,
      );

      if (response.statusCode == 200) {
        return _processAIResponse(response.data);
      } else {
        return _createErrorResponse('分析請求失敗', 'text');
      }
    } catch (e) {
      print('AI text analysis error: $e');
      return _createErrorResponse('文字分析服務暫時無法使用', 'text');
    }
  }

  /// 分析圖片內容
  Future<Map<String, dynamic>> analyzeImage({
    required String imagePath,
    List<String>? conversationHistory,
    Map<String, dynamic>? location,
  }) async {
    try {
      final currentRole = _roleService.getCurrentRole();

      MultipartFile imageFile;

      // 處理 Web 平台的 blob URL
      if (kIsWeb && (imagePath.startsWith('blob:') || imagePath.startsWith('http'))) {
        // Web blob URL - 使用 http 套件下載
        try {
          print('Downloading web image from blob URL: $imagePath');
          final response = await http.get(Uri.parse(imagePath));

          if (response.statusCode == 200) {
            imageFile = MultipartFile.fromBytes(
              response.bodyBytes,
              filename: 'web_image.jpg',
              contentType: MediaType('image', 'jpeg'),
            );
            print('Successfully downloaded image: ${response.bodyBytes.length} bytes');
          } else {
            return _createErrorResponse('無法下載 Web 圖片', 'image');
          }
        } catch (e) {
          print('Error downloading web image: $e');
          return _createErrorResponse('Web 圖片下載失敗: $e', 'image');
        }
      } else if (!kIsWeb) {
        // 移動端文件路徑
        final file = File(imagePath);
        if (!await file.exists()) {
          return _createErrorResponse('圖片檔案不存在', 'image');
        }
        imageFile = await MultipartFile.fromFile(imagePath);
      } else {
        return _createErrorResponse('不支援的圖片路徑格式', 'image');
      }

      final formData = FormData.fromMap({
        'type': 'image',
        'file': imageFile,
        'conversation_history': jsonEncode(conversationHistory ?? []),
        'location': location != null ? jsonEncode(location) : null,
      });

      final response = await _apiService.dio.post(
        '/reports/ai-analysis-json/',
        data: formData,
      );

      if (response.statusCode == 200) {
        return _processAIResponse(response.data);
      } else {
        return _createErrorResponse('圖片分析請求失敗', 'image');
      }
    } catch (e) {
      print('AI image analysis error: $e');
      return _createErrorResponse('圖片分析服務暫時無法使用', 'image');
    }
  }

  /// 分析音訊內容
  Future<Map<String, dynamic>> analyzeAudio({
    required String audioPath,
    List<String>? conversationHistory,
    Map<String, dynamic>? location,
  }) async {
    try {
      final currentRole = _roleService.getCurrentRole();

      MultipartFile audioFile;

      // 處理 Web 平台的 blob URL
      if (kIsWeb && (audioPath.startsWith('blob:') || audioPath.startsWith('http'))) {
        // Web blob URL - 使用 http 套件下載
        try {
          print('Downloading web audio from blob URL: $audioPath');
          final response = await http.get(Uri.parse(audioPath));

          if (response.statusCode == 200) {
            audioFile = MultipartFile.fromBytes(
              response.bodyBytes,
              filename: 'web_audio.m4a',
              contentType: MediaType('audio', 'mp4'),
            );
            print('Successfully downloaded audio: ${response.bodyBytes.length} bytes');
          } else {
            return _createErrorResponse('無法下載 Web 音訊', 'audio');
          }
        } catch (e) {
          print('Error downloading web audio: $e');
          return _createErrorResponse('Web 音訊下載失敗: $e', 'audio');
        }
      } else if (!kIsWeb) {
        // 移動端文件路徑
        final file = File(audioPath);
        if (!await file.exists()) {
          return _createErrorResponse('音訊檔案不存在', 'audio');
        }
        audioFile = await MultipartFile.fromFile(audioPath);
      } else {
        return _createErrorResponse('不支援的音訊路徑格式', 'audio');
      }

      final formData = FormData.fromMap({
        'type': 'audio',
        'file': audioFile,
        'conversation_history': jsonEncode(conversationHistory ?? []),
        'location': location != null ? jsonEncode(location) : null,
      });

      final response = await _apiService.dio.post(
        '/reports/ai-analysis-json/',
        data: formData,
      );

      if (response.statusCode == 200) {
        return _processAIResponse(response.data);
      } else {
        return _createErrorResponse('音訊分析請求失敗', 'audio');
      }
    } catch (e) {
      print('AI audio analysis error: $e');
      return _createErrorResponse('音訊分析服務暫時無法使用', 'audio');
    }
  }

  /// 分析影片內容
  Future<Map<String, dynamic>> analyzeVideo({
    required String videoPath,
    List<String>? conversationHistory,
    Map<String, dynamic>? location,
  }) async {
    try {
      final currentRole = _roleService.getCurrentRole();

      MultipartFile videoFile;

      // 處理 Web 平台的 blob URL
      if (kIsWeb && (videoPath.startsWith('blob:') || videoPath.startsWith('http'))) {
        // Web blob URL - 使用 http 套件下載
        try {
          print('Downloading web video from blob URL: $videoPath');
          final response = await http.get(Uri.parse(videoPath));

          if (response.statusCode == 200) {
            videoFile = MultipartFile.fromBytes(
              response.bodyBytes,
              filename: 'web_video.mp4',
              contentType: MediaType('video', 'mp4'),
            );
            print('Successfully downloaded video: ${response.bodyBytes.length} bytes');
          } else {
            return _createErrorResponse('無法下載 Web 影片', 'video');
          }
        } catch (e) {
          print('Error downloading web video: $e');
          return _createErrorResponse('Web 影片下載失敗: $e', 'video');
        }
      } else if (!kIsWeb) {
        // 移動端文件路徑
        final file = File(videoPath);
        if (!await file.exists()) {
          return _createErrorResponse('影片檔案不存在', 'video');
        }
        videoFile = await MultipartFile.fromFile(videoPath);
      } else {
        return _createErrorResponse('不支援的影片路徑格式', 'video');
      }

      final formData = FormData.fromMap({
        'type': 'video',
        'file': videoFile,
        'conversation_history': jsonEncode(conversationHistory ?? []),
        'location': location != null ? jsonEncode(location) : null,
      });

      final response = await _apiService.dio.post(
        '/reports/ai-analysis-json/',
        data: formData,
      );

      if (response.statusCode == 200) {
        return _processAIResponse(response.data);
      } else {
        return _createErrorResponse('影片分析請求失敗', 'video');
      }
    } catch (e) {
      print('AI video analysis error: $e');
      return _createErrorResponse('影片分析服務暫時無法使用', 'video');
    }
  }

  /// 分析對話並萃取報告資料
  Future<Map<String, dynamic>> analyzeConversation({
    required List<String> messages,
    bool extractReportData = false,
    Map<String, dynamic>? location,
  }) async {
    try {
      final requestData = {
        'messages': messages,
        'extract_report_data': extractReportData,
        'location': location != null ? jsonEncode(location) : null,
      };

      final response = await _apiService.dio.post(
        '/reports/conversation-analysis-json/',
        data: requestData,
      );

      if (response.statusCode == 200) {
        return _processAIResponse(response.data);
      } else {
        return _createErrorResponse('對話分析請求失敗', 'conversation');
      }
    } catch (e) {
      print('AI conversation analysis error: $e');
      return _createErrorResponse('對話分析服務暫時無法使用', 'conversation');
    }
  }

  /// 處理 AI 分析回應 (基於 ontology 標準化格式)
  Map<String, dynamic> _processAIResponse(dynamic responseData) {
    try {
      // 後端回傳的標準化 ontology JSON 格式
      if (responseData is Map<String, dynamic>) {
        final incidentAnalysis = responseData['incident_analysis'] as Map<String, dynamic>?;
        final riskEvaluation = responseData['risk_evaluation'] as Map<String, dynamic>?;
        final actionRecommendations = responseData['action_recommendations'] as Map<String, dynamic>?;
        final followUp = responseData['follow_up'] as Map<String, dynamic>?;
        final metadata = responseData['metadata'] as Map<String, dynamic>?;
        final systemInfo = responseData['system_info'] as Map<String, dynamic>?;

        return {
          'success': systemInfo?['success'] ?? true,

          // 事件分析
          'incident_type': incidentAnalysis?['incident_type'] ?? '',
          'summary': incidentAnalysis?['summary'] ?? '',
          'detailed_findings': incidentAnalysis?['detailed_findings'] ?? '',
          'analysis_confidence': incidentAnalysis?['confidence'] ?? 0.8,

          // 風險評估
          'risk_level': riskEvaluation?['level'] ?? 'medium',
          'risk_factors': riskEvaluation?['factors'] ?? [],
          'risk_description': riskEvaluation?['description'] ?? '',
          'urgency': riskEvaluation?['urgency'] ?? 'medium',

          // 建議行動 (標準化格式)
          'immediate_actions': actionRecommendations?['immediate_actions'] ?? [],
          'follow_up_actions': actionRecommendations?['follow_up_actions'] ?? [],
          'prevention_measures': actionRecommendations?['prevention_measures'] ?? [],

          // 後續追蹤
          'follow_up_questions': followUp?['questions'] ?? [],
          'required_information': followUp?['required_information'] ?? [],

          // 系統中繼資料
          'content_type': metadata?['content_type'] ?? 'unknown',
          'analysis_role': metadata?['analysis_role'] ?? 'unknown',
          'language': metadata?['language'] ?? 'zh-hant',
          'ontology_validated': systemInfo?['ontology_validated'] ?? false,
          'rag_context_used': metadata?['rag_context_used'] ?? false,
          'model_used': systemInfo?['model_used'] ?? 'gemini-2.5-pro',
          'processing_info': systemInfo ?? {},

          // 向後相容性欄位 (供舊程式碼使用)
          'risk_assessment': riskEvaluation ?? {},
          'recommendations': actionRecommendations ?? {},
          'confidence': incidentAnalysis?['confidence'] ?? 0.8,
        };
      }

      return _createErrorResponse('回應格式錯誤', 'unknown');
    } catch (e) {
      print('Error processing AI response: $e');
      return _createErrorResponse('處理 AI 回應時發生錯誤', 'unknown');
    }
  }

  /// 建立錯誤回應
  Map<String, dynamic> _createErrorResponse(String errorMessage, String contentType) {
    // 根據錯誤類型提供更好的使用者回饋
    String userFriendlyMessage;
    if (errorMessage.contains('503') || errorMessage.contains('Service Unavailable')) {
      userFriendlyMessage = 'AI 分析服務暫時繁忙，請稍後再試。您也可以直接描述狀況，我會協助您完成報告。';
    } else if (errorMessage.contains('401') || errorMessage.contains('Unauthorized')) {
      userFriendlyMessage = '認證已過期，請重新登入後再試。';
    } else if (errorMessage.contains('網路') || errorMessage.contains('network')) {
      userFriendlyMessage = '網路連線有問題，請檢查網路後重試。您也可以先手動描述狀況。';
    } else {
      userFriendlyMessage = '分析服務暫時無法使用，請直接描述您要回報的狀況，我會協助您完成報告。';
    }

    return {
      'success': false,
      'summary': '正在處理中...',
      'detailed_findings': userFriendlyMessage,
      'risk_assessment': {
        'level': 'unknown',
        'factors': ['系統暫時無法使用'],
        'description': '請手動描述狀況'
      },
      'recommendations': {
        'immediate_actions': ['直接描述狀況'],
        'follow_up_actions': ['稍後重試 AI 分析'],
        'prevention_measures': ['檢查網路連線']
      },
      'confidence': 0.0,
      'urgency': 'low',
      'follow_up_questions': [
        '請描述您看到的狀況？',
        '這個問題什麼時候發生的？',
        '是否需要立即處理？'
      ],
      'content_type': contentType,
      'analysis_role': 'system',
      'rag_context_used': false,
      'model_used': 'fallback',
      'processing_info': {'original_error': errorMessage},
    };
  }

  /// 取得角色特定的分析配置
  Future<Map<String, dynamic>> getRoleAnalysisConfig() async {
    try {
      final currentRole = _roleService.getCurrentRole();
      final roleConfig = await _roleService.getRoleConfig();

      return {
        'current_role': currentRole.key,
        'role_label': await _roleService.getRoleLabel(currentRole),
        'role_fields': _roleService.getRoleSpecificFields(currentRole),
        'backend_supported': roleConfig != null,
        'language': _languageService.getUserLanguage(),
      };
    } catch (e) {
      print('Error getting role analysis config: $e');
      return {
        'current_role': 'safety_inspector',
        'role_label': 'Safety Inspector',
        'role_fields': {},
        'backend_supported': false,
        'language': 'zh-hant',
      };
    }
  }

  /// 檢查 AI 分析服務是否可用
  Future<bool> isServiceAvailable() async {
    try {
      // 簡單的健康檢查 - 嘗試調用角色配置 API
      final response = await _apiService.dio.get('/reports/roles/config/');
      return response.statusCode == 200;
    } catch (e) {
      print('AI service availability check failed: $e');
      return false;
    }
  }
}