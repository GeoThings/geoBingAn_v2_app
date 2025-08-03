import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_generative_ai/google_generative_ai.dart';
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
      model: 'gemini-2.5-flash',
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
    
    // Use gemini-2.5-flash for multimodal vision tasks
    _visionModel = GenerativeModel(
      model: 'gemini-2.5-flash',
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
      final imageBytes = await _loadImageBytes(imagePath);
      if (imageBytes.isEmpty) {
        return {'success': false, 'error': 'Could not load image'};
      }
      
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          imagePart,
        ])
      ]);
      
      final text = response.text ?? '';
      return {'success': true, 'analysis': text};
    } catch (e) {
      print('Error analyzing image: $e');
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
        // On web, the path might be a blob URL or data URL
        // For now, return empty as web image handling requires different approach
        print('Web image loading not yet implemented');
        return [];
      } else {
        // On mobile, load the file directly
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        } else {
          print('File does not exist: $path');
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
      // For video analysis, we would extract a frame and analyze it
      // This requires video processing libraries like ffmpeg
      // For now, we'll provide guidance on what to describe
      
      final prompt = '''The user has uploaded a video for a safety incident report. 
Please ask them to describe:
- What the video shows
- When and where it was recorded
- Any safety hazards or incidents visible
- People or vehicles involved
- The duration and key moments in the video
- Any urgent safety concerns that need immediate attention''';
      
      final response = await _model.generateContent([Content.text(prompt)]);
      
      return {
        'success': true,
        'analysis': response.text ?? 'Please describe what the video shows for the incident report.'
      };
    } catch (e) {
      print('Error analyzing video: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  Future<String> transcribeAudioWithGemini(String audioPath) async {
    try {
      // Gemini doesn't directly support audio transcription
      // We need to use Google Cloud Speech-to-Text or similar service
      // For now, provide a fallback message
      
      final prompt = '''The user has sent a voice message for a safety incident report.
Please ask them to:
1. Type out what they said in the voice message, or
2. Describe the incident they want to report

Key information to gather:
- Type and nature of the incident
- Location where it occurred
- Time of occurrence
- People involved or affected
- Current safety status
- Any immediate dangers''';
      
      final response = await _model.generateContent([Content.text(prompt)]);
      
      return response.text ?? 'Please describe the incident you want to report while I process your voice message.';
    } catch (e) {
      print('Error processing audio: $e');
      return 'I had trouble processing your voice message. Please type your report instead.';
    }
  }
}