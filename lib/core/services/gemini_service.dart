import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();
  
  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;
  ChatSession? _currentChatSession;
  
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
    _currentChatSession = _model.startChat(history: [
      Content.text('''You are an AI assistant for geoBingAn, a public safety reporting system. 
Your role is to help users report incidents and safety concerns in natural language.

Key responsibilities:
1. Listen to users describe incidents or concerns
2. Ask clarifying questions to gather necessary details
3. Extract key information like location, time, type of incident, severity
4. Help users submit structured reports to the system
5. Provide guidance on emergency procedures when needed

Always maintain a professional, empathetic tone. If someone reports an emergency, 
remind them to call emergency services (112 in Taiwan) immediately.

When gathering information, ensure you collect:
- Type of incident
- Location (as specific as possible)
- Time of occurrence
- Description of what happened
- Any immediate dangers or injuries
- Contact information if follow-up is needed'''),
      Content.model([TextPart('I understand. I\'m here to help you report incidents and safety concerns. How can I assist you today?')]),
    ]);
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
      
      final response = await currentChat.sendMessage(Content.text(message));
      final text = response.text;
      print('Gemini response received: ${text?.substring(0, text.length > 100 ? 100 : text.length)}...');
      
      return text ?? 'I couldn\'t process that message. Please try again.';
    } catch (e) {
      print('Gemini API error details: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('API key')) {
        return 'API key configuration error. Please check your Gemini API key.';
      }
      return 'I\'m having trouble connecting to the AI service. Error: ${e.toString()}';
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
      final videoPart = DataPart('video/mp4', Uint8List.fromList(videoBytes));
      
      final prompt = '''You are a safety incident reporting assistant. A user has uploaded a video for their incident report.

Analyze this video and respond in natural language as if you're having a conversation with the user.

Describe what you see in the video, including:
- What is happening (describe the events you observe)
- Any safety hazards or incidents
- Location details if visible
- People, vehicles, or objects involved
- Time of day and conditions
- Severity assessment

After describing what you see, ask relevant follow-up questions to gather any missing information needed for the incident report.

IMPORTANT: Respond conversationally in plain text, NOT in JSON or structured format. Talk directly to the user about what you observed in their video.''';
      
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          videoPart,
        ])
      ]);
      
      return {
        'success': true,
        'analysis': response.text ?? 'Video analyzed. Please provide any additional context about the incident.'
      };
    } catch (e) {
      print('Error analyzing video with Gemini Pro: $e');
      return {
        'success': false,
        'analysis': 'I had trouble analyzing the video. Please describe what it shows so I can help with your report.'
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
      if (audioBytes.isEmpty && !kIsWeb) {
        return 'Could not load audio file. Please try recording again or type your message.';
      }
      
      // For web, handle appropriately
      if (kIsWeb && audioBytes.isEmpty) {
        // Web audio might be handled differently
        return 'Voice message received. Please describe the incident you want to report.';
      }
      
      // Create audio part for Gemini Pro
      final audioPart = DataPart('audio/wav', Uint8List.fromList(audioBytes));
      
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

IMPORTANT: Respond conversationally as if you're talking directly to the user. Start by acknowledging what they said in their voice message.''';
      
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          audioPart,
        ])
      ]);
      
      return response.text ?? 'I understood your voice message. Could you provide more details about the incident?';
    } catch (e) {
      print('Error processing audio with Gemini Pro: $e');
      return 'I had trouble processing your voice message. Could you please describe the incident you want to report?';
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