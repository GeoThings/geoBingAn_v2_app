import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/chat_provider.dart';
import '../../../../core/theme/app_theme.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _user = const types.User(id: 'user');
  final _ai = const types.User(
    id: 'ai',
    firstName: 'geoBingAn',
    lastName: 'Assistant',
  );
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).startNewConversation();
      _addWelcomeMessage();
    });
  }
  
  void _addWelcomeMessage() {
    final welcomeMessage = types.TextMessage(
      author: _ai,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: 'Hello! I\'m the geoBingAn assistant. I can help you report safety incidents or concerns. Please describe what you\'d like to report, and I\'ll guide you through the process.',
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
            height: 200,
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
                          Icon(Icons.photo),
                          SizedBox(width: 16),
                          Text('Photo'),
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
    // TODO: Implement image picker
  }
  
  void _handleLocationSelection() async {
    // TODO: Implement location picker
  }
  
  void _handleFileSelection() async {
    // TODO: Implement file picker
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        actions: [
          if (chatState.messages.length > 2)
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: _showReportSummary,
              tooltip: 'Review & Submit',
            ),
        ],
      ),
      body: Chat(
        messages: chatState.messages,
        onAttachmentPressed: _handleAttachmentPressed,
        onSendPressed: _handleSendPressed,
        user: _user,
        showUserAvatars: true,
        showUserNames: true,
        theme: DefaultChatTheme(
          primaryColor: Theme.of(context).primaryColor,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          inputBackgroundColor: Theme.of(context).cardColor,
          inputTextColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
          messageBorderRadius: 16,
        ),
        customBottomWidget: chatState.isTyping
            ? Container(
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
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('AI is typing...'),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}