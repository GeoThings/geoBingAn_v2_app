import 'dart:typed_data';
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
      model: 'gemini-pro',
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
    
    _visionModel = GenerativeModel(
      model: 'gemini-pro-vision',
      apiKey: AppConfig.geminiApiKey,
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
      final response = await currentChat.sendMessage(Content.text(message));
      return response.text ?? 'I couldn\'t process that message. Please try again.';
    } catch (e) {
      print('Gemini API error: $e');
      return 'I\'m having trouble connecting to the AI service. Please try again later.';
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
    // Implementation would load image from file path
    // This is a placeholder - actual implementation would use File API
    return [];
  }
}