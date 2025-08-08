import 'storage_service.dart';

class LanguageService {
  static LanguageService? _instance;
  static LanguageService get instance => _instance ??= LanguageService._();
  
  LanguageService._();
  
  final StorageService _storageService = StorageService.instance;
  
  // Get user's language preference from storage
  String getUserLanguage() {
    final storedLang = _storageService.getLanguage();
    return _mapLanguageCode(storedLang);
  }
  
  // Map language codes to full language names for Gemini
  String _mapLanguageCode(String code) {
    switch (code) {
      case 'zh-hant':
      case 'zh-TW':
        return 'Traditional Chinese (繁體中文)';
      case 'zh-hans':
      case 'zh-CN':
        return 'Simplified Chinese (简体中文)';
      case 'en':
      case 'en-US':
        return 'English';
      case 'ja':
        return 'Japanese (日本語)';
      case 'ko':
        return 'Korean (한국어)';
      case 'es':
        return 'Spanish (Español)';
      case 'fr':
        return 'French (Français)';
      case 'de':
        return 'German (Deutsch)';
      case 'pt':
        return 'Portuguese (Português)';
      case 'ru':
        return 'Russian (Русский)';
      case 'ar':
        return 'Arabic (العربية)';
      case 'hi':
        return 'Hindi (हिन्दी)';
      case 'th':
        return 'Thai (ไทย)';
      case 'vi':
        return 'Vietnamese (Tiếng Việt)';
      case 'id':
        return 'Indonesian (Bahasa Indonesia)';
      case 'ms':
        return 'Malay (Bahasa Melayu)';
      case 'fil':
      case 'tl':
        return 'Filipino (Tagalog)';
      default:
        // Default to Traditional Chinese as per app's default
        return 'Traditional Chinese (繁體中文)';
    }
  }
  
  // Get language instruction for Gemini prompts
  String getLanguageInstruction() {
    final language = getUserLanguage();
    return '\n\nIMPORTANT: Please respond ONLY in $language. Use natural, conversational language appropriate for native speakers.';
  }
  
  // Get localized welcome message
  String getWelcomeMessage() {
    final language = getUserLanguage();
    
    if (language.contains('Traditional Chinese')) {
      return '您好！我是 geoBingAn 助理。我可以幫助您報告安全事件或問題。請描述您想要報告的內容，我會引導您完成整個流程。';
    } else if (language.contains('Simplified Chinese')) {
      return '您好！我是 geoBingAn 助理。我可以帮助您报告安全事件或问题。请描述您想要报告的内容，我会引导您完成整个流程。';
    }
    
    switch (language) {
      case 'Japanese (日本語)':
        return 'こんにちは！geoBingAnアシスタントです。安全に関する事件や懸念事項の報告をお手伝いします。報告したい内容を説明してください。手続きをご案内します。';
      case 'Korean (한국어)':
        return '안녕하세요! geoBingAn 도우미입니다. 안전 사고나 우려 사항을 신고하는 것을 도와드릴 수 있습니다. 신고하고 싶은 내용을 설명해 주시면 절차를 안내해 드리겠습니다.';
      case 'Spanish (Español)':
        return 'Hola! Soy el asistente de geoBingAn. Puedo ayudarte a reportar incidentes o preocupaciones de seguridad. Por favor describe lo que quieres reportar y te guiaré a través del proceso.';
      case 'French (Français)':
        return 'Bonjour! Je suis l\'assistant geoBingAn. Je peux vous aider à signaler des incidents ou des problèmes de sécurité. Veuillez décrire ce que vous souhaitez signaler et je vous guiderai tout au long du processus.';
      default:
        return 'Hello! I\'m the geoBingAn assistant. I can help you report safety incidents or concerns. Please describe what you\'d like to report, and I\'ll guide you through the process.';
    }
  }
  
  // Get localized fallback message for web audio
  String getWebAudioFallbackMessage() {
    final language = getUserLanguage();
    
    if (language.contains('Traditional Chinese')) {
      return '''我已收到您的語音訊息。在我處理的同時，請您輸入要報告事件的關鍵細節。

請包括：
- 發生了什麼
- 何時發生
- 發生地點
- 是否有人受傷

這將幫助我為您建立準確的報告。''';
    } else if (language.contains('Simplified Chinese')) {
      return '''我已收到您的语音消息。在我处理的同时，请您输入要报告事件的关键细节。

请包括：
- 发生了什么
- 何时发生
- 发生地点
- 是否有人受伤

这将帮助我为您建立准确的报告。''';
    }
    
    switch (language) {
      case 'Japanese (日本語)':
        return '''音声メッセージを受信しました。処理中ですので、報告したい事件の詳細を入力してください。

以下を含めてください：
- 何が起きたか
- いつ発生したか
- どこで発生したか
- 負傷者がいるか

正確なレポート作成のためご協力をお願いします。''';
      case 'Korean (한국어)':
        return '''음성 메시지를 받았습니다. 처리하는 동안 신고하려는 사건의 주요 세부 사항을 입력해 주세요.

다음을 포함해 주세요:
- 무슨 일이 일어났는지
- 언제 발생했는지
- 어디서 발생했는지
- 부상자가 있는지

정확한 보고서 작성에 도움이 됩니다.''';
      default:
        return '''I received your voice message. While I'm processing it, could you please type out the key details of the incident you want to report? 

Please include:
- What happened
- When it occurred  
- Where it took place
- If anyone was injured

This will help me create an accurate report for you.''';
    }
  }
  
  // Get error message in user's language
  String getErrorMessage() {
    final language = getUserLanguage();
    
    if (language.contains('Traditional Chinese')) {
      return '處理您的訊息時遇到問題。請再試一次或輸入您的報告。';
    } else if (language.contains('Simplified Chinese')) {
      return '处理您的消息时遇到问题。请再试一次或输入您的报告。';
    }
    
    return 'I had trouble processing your message. Please try again or type your report.';
  }
}