# geoBingAn v2 App Development Notes

## Important Naming Convention
- The product name is **geoBingAn** (not GeoBingAn)
- Always use lowercase 'g' at the beginning
- This applies to all documentation, comments, and user-facing text

## Project Overview
This is a Flutter mobile application for both Android and iOS that:
1. Provides a natural language interface for users to report incidents
2. Integrates with Gemini AI for conversation processing
3. Connects to geoBingAn_v2_backend API for data submission
4. Transforms natural language into structured reports

## Key Features
- Natural language chat interface with Gemini AI
- Multi-modal capture capabilities:
  - Voice recording (web-compatible with `record` package)
  - Photo capture via device camera
  - Video recording (30-second limit)
- AI-powered conversation summarization and report extraction
- Local account authentication (email/password)
- Google OAuth integration (pending backend configuration)
- Backend API integration for report submission
- Black/white theme with red accent color (#E53935)
- Real-time token refresh and secure storage

## Authentication Implementation
### Local Authentication
- Registration: `/auth/auth/register/` with username, email, password, password_confirm, display_name
- Login: `/auth/auth/login/` with email and password
- JWT tokens stored securely using flutter_secure_storage
- Automatic token refresh on 401 responses

### OAuth (Future)
- Google OAuth ready (requires backend client_id configuration)
- LINE and Facebook OAuth prepared for future implementation
- OAuth callback handling at `/oauth/callback` route

## API Integration
- Base URL configured in `.env` file
- Dio HTTP client with interceptors for:
  - Automatic token attachment
  - Token refresh on expiry
  - Group context headers
  - Response caching

## Development Guidelines
- Follow the naming convention: geoBingAn (lowercase 'g')
- Use the existing backend API patterns from geoBingAn_v2_frontend
- Ensure cross-platform compatibility (iOS, Android, Web)
- Test authentication flow before implementing new features
- Check console for detailed error messages during development

## Recent Updates
### Gemini 2.5 Pro Integration (Latest)
- Upgraded from Gemini 2.5 Flash to Gemini 2.5 Pro model for better multimodal support
- Implemented native audio, video, and image processing without external STT services
- **Audio Format Fix**: Resolved Gemini internal errors by switching to M4A format (AAC-LC codec)
  - Previous formats (WebM, PCM16) caused compatibility issues
  - M4A provides cross-platform compatibility between web and mobile
- Added language support based on user profile settings (Traditional Chinese default)
- Fixed JSON responses from video analysis with conversational formatting
- Fixed dark theme support for chat bubbles
- Added detailed error logging for debugging
- See [AI.md](AI.md) for complete prompt documentation and lessons learned

### Voice/Photo/Video Capture
- Implemented multi-modal capture with mode switcher UI
- Added large red capture button above text input
- Voice recording works on web using dummy path with `record` package
- Photo and video capture using `image_picker` package
- Attachment icon on right side of text input for file uploads
- Fixed web compatibility issues with path_provider

### UI/UX Improvements
- Changed app bar title from "Report Incident" to "Make a Report"
- Implemented recording overlay with animated stop button
- Mode selector with Voice/Photo/Video options
- Visual feedback for active recording state
- Dark mode support with proper theming for chat interface