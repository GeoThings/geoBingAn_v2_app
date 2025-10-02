import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart' as camera;
import 'dart:io';
import 'dart:typed_data';
import '../../providers/chat_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/ai_analysis_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/role_service.dart';
import '../widgets/camera_capture_screen.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

enum CaptureMode { voice, photo, video }

class _ChatPageState extends ConsumerState<ChatPage> {
  final _user = const types.User(id: 'user');
  final _ai = const types.User(
    id: 'ai',
    firstName: 'geoBingAn',
    lastName: 'Assistant',
  );
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  CaptureMode _captureMode = CaptureMode.voice;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).startNewConversation();
      _addWelcomeMessage();
      _checkMicrophonePermission();
    });
  }
  
  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }
  
  Future<void> _checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }
  
  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }
  
  void _handleCapture() {
    switch (_captureMode) {
      case CaptureMode.voice:
        if (_isRecording) {
          _stopRecording();
        } else {
          _startRecording();
        }
        break;
      case CaptureMode.photo:
        _capturePhoto();
        break;
      case CaptureMode.video:
        _captureVideo();
        break;
    }
  }
  
  Future<void> _capturePhoto() async {
    try {
      if (kIsWeb) {
        // Use camera package for web to get live camera
        final camera.XFile? photo = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CameraCaptureScreen(isVideo: false),
          ),
        );
        
        if (photo != null) {
          print('Photo captured on web: ${photo.path}');
          _sendMediaToAI(photo.path, 'photo');
        }
      } else {
        // Use image_picker for mobile (works with native camera)
        await _checkCameraPermission();
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        
        if (photo != null) {
          print('Photo captured: ${photo.path}');
          print('Photo name: ${photo.name}');
          _sendMediaToAI(photo.path, 'photo');
        } else {
          print('No photo captured');
        }
      }
    } catch (e) {
      print('Error capturing photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  Future<void> _captureVideo() async {
    try {
      if (kIsWeb) {
        // Use camera package for web to get live camera
        final camera.XFile? video = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CameraCaptureScreen(isVideo: true),
          ),
        );
        
        if (video != null) {
          print('Video captured on web: ${video.path}');
          _sendMediaToAI(video.path, 'video');
        }
      } else {
        // Use image_picker for mobile (works with native camera)
        await _checkCameraPermission();
        final ImagePicker picker = ImagePicker();
        final XFile? video = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 30),
        );
        
        if (video != null) {
          print('Video captured: ${video.path}');
          print('Video name: ${video.name}');
          _sendMediaToAI(video.path, 'video');
        } else {
          print('No video captured');
        }
      }
    } catch (e) {
      print('Error capturing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture video: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  Future<void> _sendMediaToAI(String mediaPath, String mediaType) async {
    // Create a message showing media was sent
    final icon = mediaType == 'photo' ? '📷' : '🎥';
    final mediaMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: '$icon ${mediaType == 'photo' ? 'Photo' : 'Video'} captured',
    );
    
    ref.read(chatProvider.notifier).addMessage(mediaMessage);
    ref.read(chatProvider.notifier).setTyping(true);
    
    try {
      String response;
      if (mediaType == 'photo') {
        // Analyze photo with Gemini Vision
        response = await ref.read(chatProvider.notifier).analyzeImage(mediaPath);
      } else {
        // For video, extract a frame and analyze it
        // Note: Full video analysis requires more complex processing
        response = await ref.read(chatProvider.notifier).analyzeVideo(mediaPath);
      }
      
      final responseMessage = types.TextMessage(
        author: _ai,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: response,
      );
      
      ref.read(chatProvider.notifier).addMessage(responseMessage);
    } catch (e) {
      print('Error analyzing media: $e');
      final errorMessage = types.TextMessage(
        author: _ai,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: 'I received your $mediaType but encountered an error during analysis. Please describe what you captured.',
      );
      ref.read(chatProvider.notifier).addMessage(errorMessage);
    } finally {
      ref.read(chatProvider.notifier).setTyping(false);
    }
  }
  
  Future<void> _startRecording() async {
    try {
      // Check microphone permission for all platforms
      if (await _audioRecorder.hasPermission()) {
        String path;
        
        if (kIsWeb) {
          // For web platform, use a dummy path (the package handles web recording internally)
          path = 'audio_recording_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          // For mobile platforms, save to file
          final directory = await getApplicationDocumentsDirectory();
          path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        _currentRecordingPath = path;
        
        // Use M4A format for better Gemini compatibility
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,  // AAC-LC encoder for M4A format
            bitRate: 128000,  // 128 kbps for good quality
            sampleRate: 44100,  // Standard sample rate for M4A
            numChannels: 1,     // Mono for smaller file size
          ),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording started...'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice recording'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });
      
      if (path != null) {
        print('Audio recording stopped, path: $path');
        // Send the actual path (blob URL on web, file path on mobile)
        _sendAudioToAI(path);
      } else {
        print('No path returned from audio recorder');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio was recorded. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording stopped'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  Future<void> _sendAudioToAI(String audioPath) async {
    // Create a message showing audio was sent
    final audioMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: '🎤 Voice message recorded',
    );
    
    ref.read(chatProvider.notifier).addMessage(audioMessage);
    ref.read(chatProvider.notifier).setTyping(true);
    
    try {
      // Process audio with Gemini Pro
      final response = await ref.read(chatProvider.notifier).transcribeAudio(audioPath);
      
      if (response.isNotEmpty) {
        // Show Gemini's response about the audio
        final responseMessage = types.TextMessage(
          author: _ai,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: response,
        );
        ref.read(chatProvider.notifier).addMessage(responseMessage);
      } else {
        // Fallback message if no response
        final responseMessage = types.TextMessage(
          author: _ai,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: 'I received your voice message. Please type or describe what you wanted to report.',
        );
        ref.read(chatProvider.notifier).addMessage(responseMessage);
      }
    } catch (e) {
      print('Error processing audio: $e');
      final errorMessage = types.TextMessage(
        author: _ai,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: 'I had trouble processing your voice message. Please try recording again or type your message instead.',
      );
      ref.read(chatProvider.notifier).addMessage(errorMessage);
    } finally {
      ref.read(chatProvider.notifier).setTyping(false);
    }
    
    // Clean up the audio file only on mobile platforms
    if (!kIsWeb && audioPath != 'web_audio_stream' && audioPath.contains('/')) {
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting audio file: $e');
      }
    }
  }
  
  void _addWelcomeMessage() async {
    final roleService = RoleService.instance;
    final currentRole = roleService.getCurrentRole();
    final welcomeText = await roleService.getRoleWelcomeMessage(currentRole);
    
    final welcomeMessage = types.TextMessage(
      author: _ai,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: welcomeText,
    );
    ref.read(chatProvider.notifier).addMessage(welcomeMessage);
  }
  
  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );
    
    ref.read(chatProvider.notifier).addMessage(textMessage);
    
    ref.read(chatProvider.notifier).setTyping(true);
    
    final response = await ref.read(chatProvider.notifier).sendMessageToAI(message.text);
    
    final responseMessage = types.TextMessage(
      author: _ai,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: response,
    );
    
    ref.read(chatProvider.notifier).addMessage(responseMessage);
    ref.read(chatProvider.notifier).setTyping(false);
  }
  
  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleImageSelection();
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.photo_library),
                          SizedBox(width: 16),
                          Text('Choose Photo from Gallery'),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleVideoSelection();
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.video_library),
                          SizedBox(width: 16),
                          Text('Choose Video from Gallery'),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLocationSelection();
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on),
                          SizedBox(width: 16),
                          Text('Current Location'),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file),
                          SizedBox(width: 16),
                          Text('File'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _handleImageSelection() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        print('Image selected from gallery: ${image.path}');
        _sendMediaToAI(image.path, 'photo');
      }
    } catch (e) {
      print('Error selecting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  void _handleVideoSelection() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      
      if (video != null) {
        print('Video selected from gallery: ${video.path}');
        _sendMediaToAI(video.path, 'video');
      }
    } catch (e) {
      print('Error selecting video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select video: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  void _handleLocationSelection() async {
    // TODO: Implement location picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location sharing coming soon'),
      ),
    );
  }
  
  void _handleFileSelection() async {
    // TODO: Implement file picker for other document types if needed
  }
  
  void _showReportSummary() {
    final messages = ref.read(chatProvider).messages;
    final conversation = messages
        .where((m) => m is types.TextMessage)
        .map((m) => '${m.author.id}: ${(m as types.TextMessage).text}')
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ready to submit your report?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: ref.read(chatProvider.notifier).extractReportData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  
                  final data = snapshot.data ?? {};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryItem('Type', data['incident_type']),
                      _buildSummaryItem('Location', data['location']),
                      _buildSummaryItem('Time', data['time']),
                      _buildSummaryItem('Severity', data['severity']),
                      _buildSummaryItem('Description', data['description']),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Editing'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitReport();
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'Not provided',
              style: TextStyle(
                color: value == null ? Colors.orange : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitReport() async {
    final success = await ref.read(chatProvider.notifier).submitReport();
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit report. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Report'),
        actions: [
          if (chatState.messages.length > 2)
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: _showReportSummary,
              tooltip: 'Review & Submit',
            ),
        ],
      ),
      body: Stack(
        children: [
          Chat(
            messages: chatState.messages,
            onAttachmentPressed: _handleAttachmentPressed,
            onSendPressed: _handleSendPressed,
            user: _user,
            showUserAvatars: true,
            showUserNames: true,
            theme: isDark
                ? DarkChatTheme(
                    primaryColor: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Colors.black,
                    inputBackgroundColor: Colors.grey[900]!,
                    inputTextColor: Colors.white,
                    messageBorderRadius: 16,
                    receivedMessageBodyTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    sentMessageBodyTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : DefaultChatTheme(
                    primaryColor: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Colors.white,
                    inputBackgroundColor: Colors.grey[100]!,
                    inputTextColor: Colors.black87,
                    messageBorderRadius: 16,
                    receivedMessageBodyTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    sentMessageBodyTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            customBottomWidget: _buildCustomInputBar(context, isDark, chatState),
          ),
          // Large recording button overlay
          if (_isRecording)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black87 : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                            ),
                          ),
                          GestureDetector(
                            onTap: _stopRecording,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              child: const Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Recording...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to stop',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCustomInputBar(BuildContext context, bool isDark, chatState) {
    if (chatState.isTyping) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('AI is typing...'),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeButton(CaptureMode.voice, Icons.mic, 'Voice', isDark),
              const SizedBox(width: 16),
              _buildModeButton(CaptureMode.photo, Icons.camera_alt, 'Photo', isDark),
              const SizedBox(width: 16),
              _buildModeButton(CaptureMode.video, Icons.videocam, 'Video', isDark),
            ],
          ),
          const SizedBox(height: 16),
          // Large capture button
          GestureDetector(
            onTap: _handleCapture,
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _getCaptureIcon(),
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          // Text input with attachment button
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Say something about the situation',
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      _handleSendPressed(types.PartialText(text: text));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _handleAttachmentPressed,
                icon: Icon(
                  Icons.attach_file,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeButton(CaptureMode mode, IconData icon, String label, bool isDark) {
    final isSelected = _captureMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _captureMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondary
                : isDark ? Colors.white24 : Colors.black26,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                  ? Theme.of(context).colorScheme.secondary
                  : isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected 
                    ? Theme.of(context).colorScheme.secondary
                    : isDark ? Colors.white70 : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getCaptureIcon() {
    switch (_captureMode) {
      case CaptureMode.voice:
        return _isRecording ? Icons.stop : Icons.mic;
      case CaptureMode.photo:
        return Icons.camera_alt;
      case CaptureMode.video:
        return Icons.videocam;
    }
  }
}