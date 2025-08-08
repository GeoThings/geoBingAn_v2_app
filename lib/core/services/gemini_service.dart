import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'language_service.dart';

class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();
  
  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;
  ChatSession? _currentChatSession;
  final LanguageService _languageService = LanguageService.instance;
  
  GeminiService._() {
    _initializeModels();
  }
  
  void _initializeModels() {
    if (AppConfig.geminiApiKey.isEmpty) {
      throw Exception('Gemini API key is not configured');
    }
    
    _model = GenerativeModel(
      model: 'gemini-2.5-pro',
      apiKey: AppConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
    
    // Use gemini-2.5-pro for multimodal tasks (audio, video, images)
    _visionModel = GenerativeModel(
      model: 'gemini-2.5-pro',
      apiKey: AppConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        topK: 32,
        topP: 1,
        maxOutputTokens: 4096,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }
  
  void startNewChat() {
    _currentChatSession = _model.startChat(history: []);
  }
  
  ChatSession get currentChat {
    if (_currentChatSession == null) {
      startNewChat();
    }
    return _currentChatSession!;
  }
  
  Future<String> sendMessage(String message) async {
    try {
      print('Sending message to Gemini: $message');
      print('API Key configured: ${AppConfig.geminiApiKey.isNotEmpty}');
      
      // Add context and language instruction to the message
      final languageInstruction = _languageService.getLanguageInstruction();
      final contextualMessage = '''You are an AI assistant for geoBingAn, a public safety reporting system helping users report incidents.

User message: $message

Please respond conversationally to help gather incident details including location, time, type of incident, and severity.$languageInstruction''';
      
      final response = await currentChat.sendMessage(Content.text(contextualMessage));
      final text = response.text;
      print('Gemini response received: ${text?.substring(0, text.length > 100 ? 100 : text.length)}...');
      
      return text ?? 'I couldn\'t process that message. Please try again.';
    } catch (e) {
      print('Gemini API error details: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('API key')) {
        return 'API key configuration error. Please check your Gemini API key.';
      }
      if (e.toString().contains('Format')) {
        return 'I had trouble understanding that. Could you please rephrase your message?';
      }
      return 'I\'m having trouble connecting to the AI service. Please try again.';
    }
  }
  
  Future<Map<String, dynamic>> extractReportData(List<String> conversation) async {
    final prompt = '''Based on this conversation, extract the following information for a safety report:

Conversation:
${conversation.join('\n')}

Please extract and return in JSON format:
{
  "incident_type": "type of incident",
  "location": "specific location or address",
  "time": "when it occurred",
  "description": "detailed description",
  "severity": "low/medium/high/critical",
  "requires_immediate_attention": true/false,
  "contact_info": "any provided contact information",
  "additional_notes": "any other relevant information"
}

If any information is missing, use null for that field.''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = text.substring(jsonStart, jsonEnd);
        return _parseJson(jsonStr);
      }
      return {};
    } catch (e) {
      print('Error extracting report data: $e');
      return {};
    }
  }
  
  Future<String> summarizeConversation(List<String> messages) async {
    final prompt = '''Please provide a concise summary of this conversation about a safety incident or concern:

${messages.join('\n')}

Summary (2-3 sentences):''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate summary.';
    } catch (e) {
      print('Error summarizing conversation: $e');
      return 'Unable to generate summary.';
    }
  }
  
  Future<Map<String, dynamic>> analyzeImageWithText(
    String imagePath,
    String prompt,
  ) async {
    try {
      print('Analyzing image: $imagePath');
      final imageBytes = await _loadImageBytes(imagePath);
      if (imageBytes.isEmpty) {
        print('Failed to load image bytes from: $imagePath');
        return {'success': false, 'error': 'Could not load image data'};
      }
      
      print('Creating image part with ${imageBytes.length} bytes');
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      
      print('Sending image to Gemini Pro for analysis...');
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          imagePart,
        ])
      ]);
      
      final text = response.text ?? '';
      print('Gemini Pro image analysis complete: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
      return {'success': true, 'analysis': text};
    } catch (e) {
      print('Error analyzing image with Gemini: $e');
      print('Stack trace: ${StackTrace.current}');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  String _convertJsonToConversational(String text) {
    // Clean up the text first
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    
    // Extract events from JSON-like structure
    final List<String> events = [];
    
    // Try to parse the events with a more flexible regex
    final regex = RegExp(r'"label"\s*:\s*"([^"]+)"', multiLine: true);
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      if (match.group(1) != null) {
        String event = match.group(1)!;
        // Clean up newlines and extra spaces
        event = event.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        events.add(event);
      }
    }
    
    // If we found events, convert to conversational format in user's language
    if (events.isNotEmpty) {
      final userLanguage = _languageService.getUserLanguage();
      String conversational = '';
      String followUp = '';
      
      // Create response based on user's language
      if (userLanguage.contains('Traditional Chinese')) {
        conversational = '我在您的影片中看到';
        
        if (events.length == 1) {
          conversational += '${events[0]}。';
        } else {
          conversational += '發生了幾件事：';
          for (int i = 0; i < events.length; i++) {
            if (i == 0) {
              conversational += '首先，${events[i]}。';
            } else if (i == events.length - 1) {
              conversational += '最後，${events[i]}。';
            } else {
              conversational += '然後，${events[i]}。';
            }
          }
        }
        
        followUp = '\n\n請告訴我更多關於這個事件的資訊。這是什麼時候、在哪裡發生的？有人受傷或處於危險中嗎？';
      } else if (userLanguage.contains('Simplified Chinese')) {
        conversational = '我在您的视频中看到';
        
        if (events.length == 1) {
          conversational += '${events[0]}。';
        } else {
          conversational += '发生了几件事：';
          for (int i = 0; i < events.length; i++) {
            if (i == 0) {
              conversational += '首先，${events[i]}。';
            } else if (i == events.length - 1) {
              conversational += '最后，${events[i]}。';
            } else {
              conversational += '然后，${events[i]}。';
            }
          }
        }
        
        followUp = '\n\n请告诉我更多关于这个事件的信息。这是什么时候、在哪里发生的？有人受伤或处于危险中吗？';
      } else {
        // Default to English
        conversational = 'I can see in your video that ';
        
        if (events.length == 1) {
          conversational += '${events[0].toLowerCase()}. ';
        } else {
          conversational += 'several things happen: ';
          for (int i = 0; i < events.length; i++) {
            if (i == 0) {
              conversational += 'First, ${events[i].toLowerCase()}. ';
            } else if (i == events.length - 1) {
              conversational += 'Finally, ${events[i].toLowerCase()}. ';
            } else {
              conversational += 'Then, ${events[i].toLowerCase()}. ';
            }
          }
        }
        
        followUp = '\n\nCould you tell me more about this incident? When and where did this occur? Was anyone injured or in danger?';
      }
      
      return conversational + followUp;
    }
    
    // If not JSON or couldn't parse, return original text
    return text;
  }
  
  Map<String, dynamic> _parseJson(String jsonStr) {
    try {
      jsonStr = jsonStr.replaceAll(RegExp(r'[\n\r\t]'), ' ');
      jsonStr = jsonStr.replaceAll(RegExp(r'\s+'), ' ');
      
      final Map<String, dynamic> result = {};
      final regex = RegExp(r'"([^"]+)"\s*:\s*("([^"]*)"|(true|false|null|\d+\.?\d*))');
      final matches = regex.allMatches(jsonStr);
      
      for (final match in matches) {
        final key = match.group(1)!;
        final value = match.group(3) ?? match.group(4);
        
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value == 'null') {
          result[key] = null;
        } else if (value != null && RegExp(r'^\d+\.?\d*$').hasMatch(value)) {
          result[key] = num.parse(value);
        } else {
          result[key] = value;
        }
      }
      
      return result;
    } catch (e) {
      print('Error parsing JSON: $e');
      return {};
    }
  }
  
  Future<List<int>> _loadImageBytes(String path) async {
    try {
      if (kIsWeb) {
        print('Web image processing - path: $path');
        
        // On web, image_picker returns a blob URL or network path
        if (path.startsWith('blob:') || path.startsWith('http')) {
          print('Fetching image from URL: $path');
          try {
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              print('Successfully fetched image, size: ${response.bodyBytes.length} bytes');
              return response.bodyBytes;
            } else {
              print('Failed to fetch image: ${response.statusCode}');
              return [];
            }
          } catch (e) {
            print('Error fetching image URL: $e');
            return [];
          }
        } else {
          print('Unexpected image path format on web: $path');
          return [];
        }
      } else {
        // On mobile, load the file directly
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          print('Loaded image file, size: ${bytes.length} bytes');
          return bytes;
        } else {
          print('Image file does not exist: $path');
          return [];
        }
      }
    } catch (e) {
      print('Error loading image bytes: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> analyzeVideoFrame(String videoPath) async {
    try {
      // Gemini 2.5 Pro supports native video input
      final videoBytes = await _loadVideoBytes(videoPath);
      if (videoBytes.isEmpty) {
        return {
          'success': false,
          'analysis': 'Could not load video. Please describe what the video shows.'
        };
      }
      
      // Create video part for Gemini Pro
      // Web typically records as webm, mobile as mp4
      final mimeType = kIsWeb ? 'video/webm' : 'video/mp4';
      final videoPart = DataPart(mimeType, Uint8List.fromList(videoBytes));
      
      final languageInstruction = _languageService.getLanguageInstruction();
      final prompt = '''You are a safety incident reporting assistant having a conversation with a user who uploaded a video.

CRITICAL INSTRUCTIONS:
1. DO NOT output JSON, arrays, or any structured data format
2. Write in complete sentences as if speaking to the user
3. Use natural, conversational language
4. Start with "I can see in your video..." or similar phrase

Analyze the video and describe:
- What is happening throughout the video
- Any safety concerns or incidents
- People, vehicles, or objects involved
- Location and time indicators
- Severity of any incidents

Then ask follow-up questions about:
- When this occurred
- Exact location
- Anyone injured or in danger
- What led to this incident

Example response format:
"I can see in your video that [describe what happens]. This appears to be [assessment]. Can you tell me when this incident occurred and if anyone was injured?"

Remember: Write as if having a conversation, NOT as data or JSON.$languageInstruction''';
      
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          videoPart,
        ])
      ]);
      
      String analysisText = response.text ?? '';
      print('Raw Gemini video response: $analysisText');
      
      // Post-process to ensure conversational format
      if (analysisText.contains('json') || analysisText.contains('[{')) {
        print('Detected JSON in response, converting to conversational format');
        analysisText = _convertJsonToConversational(analysisText);
        print('Converted response: $analysisText');
      }
      
      // Get fallback message in user's language if needed
      String fallbackMessage;
      final userLanguage = _languageService.getUserLanguage();
      if (userLanguage.contains('Traditional Chinese')) {
        fallbackMessage = '我已分析了您的影片。請提供更多關於事件發生的時間和詳細情況。';
      } else if (userLanguage.contains('Simplified Chinese')) {
        fallbackMessage = '我已分析了您的视频。请提供更多关于事件发生的时间和详细情况。';
      } else {
        fallbackMessage = 'I\'ve analyzed your video. Could you provide more details about what happened and when this incident occurred?';
      }
      
      return {
        'success': true,
        'analysis': analysisText.isNotEmpty 
            ? analysisText 
            : fallbackMessage
      };
    } catch (e) {
      print('Error analyzing video with Gemini Pro: $e');
      
      // Get error message in user's language
      String errorMessage;
      final userLanguage = _languageService.getUserLanguage();
      if (userLanguage.contains('Traditional Chinese')) {
        errorMessage = '我無法分析這個影片。請描述影片中顯示的內容，以便我協助您完成報告。';
      } else if (userLanguage.contains('Simplified Chinese')) {
        errorMessage = '我无法分析这个视频。请描述视频中显示的内容，以便我协助您完成报告。';
      } else {
        errorMessage = 'I had trouble analyzing the video. Please describe what it shows so I can help with your report.';
      }
      
      return {
        'success': false,
        'analysis': errorMessage
      };
    }
  }
  
  Future<List<int>> _loadVideoBytes(String path) async {
    try {
      if (kIsWeb) {
        print('Web video processing - path: $path');
        
        // On web, video might be a blob URL
        if (path.startsWith('blob:') || path.startsWith('http')) {
          print('Fetching video from URL: $path');
          try {
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              final fileSize = response.bodyBytes.length;
              // Check file size (limit to 20MB for Gemini Pro)
              if (fileSize > 20 * 1024 * 1024) {
                print('Video file too large: ${fileSize / 1024 / 1024}MB');
                return [];
              }
              print('Successfully fetched video, size: ${fileSize} bytes');
              return response.bodyBytes;
            } else {
              print('Failed to fetch video: ${response.statusCode}');
              return [];
            }
          } catch (e) {
            print('Error fetching video URL: $e');
            return [];
          }
        } else {
          print('Unexpected video path format on web: $path');
          return [];
        }
      } else {
        // On mobile, load the file directly
        final file = File(path);
        if (await file.exists()) {
          // Check file size (Gemini Pro supports larger files, but let's limit to 20MB)
          final fileSize = await file.length();
          if (fileSize > 20 * 1024 * 1024) {
            print('Video file too large: ${fileSize / 1024 / 1024}MB');
            return [];
          }
          final bytes = await file.readAsBytes();
          print('Loaded video file, size: ${bytes.length} bytes');
          return bytes;
        } else {
          print('Video file does not exist: $path');
          return [];
        }
      }
    } catch (e) {
      print('Error loading video bytes: $e');
      return [];
    }
  }
  
  Future<String> transcribeAudioWithGemini(String audioPath) async {
    try {
      // Gemini 2.5 Pro supports native audio input
      final audioBytes = await _loadAudioBytes(audioPath);
      if (audioBytes.isEmpty) {
        return 'Could not load audio file. Please try recording again or type your message.';
      }
      
      // Audio is now recorded as M4A (AAC-LC)
      // Use audio/mp4 MIME type for M4A format
      String mimeType = 'audio/mp4';  // MIME type for M4A/AAC audio
      
      if (kIsWeb) {
        print('Web audio: M4A format, ${audioBytes.length} bytes');
      } else {
        print('Mobile audio: M4A format, ${audioBytes.length} bytes');
      }
      
      // Create audio part for Gemini Pro with M4A format
      final audioPart = DataPart(mimeType, Uint8List.fromList(audioBytes));
      print('Sending M4A audio to Gemini Pro: ${audioBytes.length} bytes as $mimeType');
      
      final languageInstruction = _languageService.getLanguageInstruction();
      final prompt = '''You are a safety incident reporting assistant. Listen to this voice message from a user reporting an incident.

First, acknowledge what you heard in the audio message by summarizing what the user said.

Then, have a natural conversation with the user about their report. Consider:
- Type and nature of the incident
- Location where it occurred
- Time of occurrence
- People involved or affected
- Current safety status
- Any immediate dangers

Ask follow-up questions to gather any missing information needed for a complete incident report.

IMPORTANT: Respond conversationally as if you're talking directly to the user. Start by acknowledging what they said in their voice message.$languageInstruction''';
      
      try {
        // Send audio to Gemini 2.5 Pro using multimodal model
        print('Sending to Gemini 2.5 Pro multimodal model...');
        final response = await _visionModel.generateContent([
          Content.multi([
            TextPart(prompt),
            audioPart,
          ])
        ]);
        
        final responseText = response.text;
        print('Gemini audio response received: ${responseText?.substring(0, responseText.length > 100 ? 100 : responseText.length)}...');
        
        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        } else {
          // Fallback if no response
          return _languageService.getWebAudioFallbackMessage();
        }
      } catch (audioError) {
        print('Error sending audio to Gemini: $audioError');
        // If Gemini can't process the audio, provide helpful fallback
        return _languageService.getWebAudioFallbackMessage();
      }
    } catch (e) {
      print('Error in transcribeAudioWithGemini: $e');
      return _languageService.getErrorMessage();
    }
  }
  
  Future<List<int>> _loadAudioBytes(String path) async {
    try {
      if (kIsWeb) {
        // On web, the record package returns a blob URL
        print('Web audio processing - path: $path');
        
        // Check if it's a blob URL
        if (path.startsWith('blob:')) {
          print('Fetching audio from blob URL: $path');
          try {
            // Fetch the blob data
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              print('Successfully fetched audio blob, size: ${response.bodyBytes.length} bytes');
              return response.bodyBytes;
            } else {
              print('Failed to fetch blob: ${response.statusCode}');
              return [];
            }
          } catch (e) {
            print('Error fetching blob URL: $e');
            return [];
          }
        } else {
          // If not a blob URL, might be a placeholder
          print('Web audio path is not a blob URL: $path');
          return [];
        }
      } else {
        // On mobile, load the audio file directly
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          print('Loaded audio file, size: ${bytes.length} bytes');
          return bytes;
        } else {
          print('Audio file does not exist: $path');
          return [];
        }
      }
    } catch (e) {
      print('Error loading audio bytes: $e');
      return [];
    }
  }
}