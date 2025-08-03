# geoBingAn v2 Mobile App

A Flutter mobile application for iOS and Android that enables natural language incident reporting with AI assistance.

## Features

- **Natural Language Chat Interface**: Report incidents by having a conversation with AI
- **Gemini AI Integration**: Intelligent conversation processing and report extraction
- **Google OAuth Authentication**: Secure sign-in with Google account (LINE and native auth coming soon)
- **Multi-language Support**: Traditional Chinese, Simplified Chinese, and English
- **Dark/Light Theme**: Black and white based design with red accent color
- **Real-time Report Submission**: Seamless integration with geoBingAn v2 backend API

## Architecture

The app follows a clean architecture pattern with:
- **Feature-based organization**: Each feature has its own presentation, domain, and data layers
- **State Management**: Flutter Riverpod for reactive state management
- **API Integration**: Dio for HTTP requests with token refresh and caching
- **Secure Storage**: Flutter Secure Storage for sensitive data

## Setup

1. **Prerequisites**
   - Flutter SDK 3.0+
   - Android Studio or Xcode
   - geoBingAn v2 backend running locally or deployed

2. **Configuration**
   - Copy `.env.example` to `.env`
   - Add your API keys:
     ```
     API_BASE_URL=http://localhost:8000/api
     GEMINI_API_KEY=your_gemini_api_key
     GOOGLE_MAPS_API_KEY=your_google_maps_api_key
     ```

3. **Installation**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/
│   ├── config/         # App configuration
│   ├── services/       # Core services (API, Gemini, Storage)
│   └── theme/          # App theme definitions
├── features/
│   ├── auth/           # Authentication feature
│   ├── chat/           # Chat & AI interaction
│   └── home/           # Home dashboard
└── main.dart           # App entry point
```

## Key Components

### Chat Interface
- Powered by `flutter_chat_ui` for a polished messaging experience
- Real-time AI responses using Gemini Pro
- Support for attachments (images, location, files)
- Automatic report data extraction from conversations

### Authentication
- Google OAuth 2.0 integration
- Token-based authentication with automatic refresh
- Secure token storage

### Report Submission
- Converts natural language to structured reports
- Extracts key information: location, time, severity, description
- Submits to backend in geoBingAn v2 format

## Development

### Adding New Features
1. Create a new feature folder under `lib/features/`
2. Implement presentation, providers, and services
3. Add routes in `main.dart`

### API Integration
- All API calls go through `ApiService` with automatic token handling
- Add new endpoints in `lib/core/services/api_service.dart`

### Theming
- Theme colors and styles defined in `lib/core/theme/app_theme.dart`
- Black/white base with red accent (#E53935)

## Contributing

Please follow the existing code patterns and ensure:
- Product name is always `geoBingAn` (lowercase 'g')
- Maintain black/white/red color scheme
- Test on both iOS and Android platforms

## License

Private repository - All rights reserved