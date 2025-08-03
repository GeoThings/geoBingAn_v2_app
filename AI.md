# AI Integration Documentation - geoBingAn v2 App

## Overview
The geoBingAn v2 app uses Google's Gemini 2.5 Flash model for natural language processing and multimodal analysis. This document outlines all AI prompts, context, and interaction logic.

## Model Configuration
- **Primary Model**: `gemini-2.5-flash`
- **Vision Model**: `gemini-2.5-flash` (multimodal)
- **Temperature**: 0.7 (chat), 0.4 (vision)
- **Max Output Tokens**: 1024 (chat), 4096 (vision)

## AI Prompts and Context

### 1. Initial Chat Context
When a new conversation starts, the AI assistant is initialized with this context:

```
You are an AI assistant for geoBingAn, a public safety reporting system. 
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
- Contact information if follow-up is needed
```

### 2. Image Analysis Prompt
When a user captures a photo, the AI analyzes it with this prompt:

```
Analyze this image for a safety incident report. 
Describe what you see, including:
- What is happening or what happened
- Any visible hazards or safety concerns
- Location details if visible
- People or vehicles involved
- Any damage or injuries visible
- Time of day if determinable
- Weather conditions if relevant

Provide a clear, detailed description that would help authorities understand the situation.
```

### 3. Report Data Extraction
After the conversation, the AI extracts structured data using this prompt:

```
Based on this conversation, extract the following information for a safety report:

Conversation:
[user and AI messages]

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

If any information is missing, use null for that field.
```

### 4. Conversation Summarization
For the final report submission, the AI creates a summary:

```
Please provide a concise summary of this conversation about a safety incident or concern:

[conversation messages]

Summary (2-3 sentences):
```

### 5. Voice Message Handling
When a voice message is received (transcription not yet available):

```
The user has sent a voice message for a safety incident report.
Please ask them to:
1. Type out what they said in the voice message, or
2. Describe the incident they want to report

Key information to gather:
- Type and nature of the incident
- Location where it occurred
- Time of occurrence
- People involved or affected
- Current safety status
- Any immediate dangers
```

### 6. Video Analysis
When a video is uploaded:

```
The user has uploaded a video for a safety incident report. 
Please ask them to describe:
- What the video shows
- When and where it was recorded
- Any safety hazards or incidents visible
- People or vehicles involved
- The duration and key moments in the video
- Any urgent safety concerns that need immediate attention
```

## Conversation Flow

1. **Initialization**: Chat session starts with the safety reporting context
2. **User Input**: Can be text, voice, photo, or video
3. **AI Processing**: 
   - Text: Direct conversation with context
   - Photo: Vision analysis + contextual questions
   - Voice: Request for typed description
   - Video: Request for video description
4. **Information Gathering**: AI asks clarifying questions based on missing information
5. **Report Extraction**: Structured data extracted from conversation
6. **Summary Generation**: Create concise report summary
7. **Submission**: Final report sent to backend API

## Safety Features

- **Emergency Detection**: AI reminds users to call 112 (Taiwan emergency) when detecting urgent situations
- **Harm Filtering**: All content filtered through Gemini's safety settings (medium threshold)
- **Professional Tone**: Maintains empathetic and professional communication
- **Data Validation**: Ensures critical information is collected before submission

## Error Handling

- **API Failures**: Graceful fallback messages
- **Missing Data**: AI prompts for required information
- **Media Processing Errors**: Alternative text-based reporting options

## Future Enhancements

- Audio transcription via Google Cloud Speech-to-Text
- Video frame extraction and analysis
- Real-time location detection
- Multi-language support (currently supports English, Traditional Chinese, Simplified Chinese)
- Integration with emergency services APIs

## Technical Implementation

- **Service**: `GeminiService` (lib/core/services/gemini_service.dart)
- **Provider**: `ChatProvider` (lib/features/chat/providers/chat_provider.dart)
- **UI**: `ChatPage` (lib/features/chat/presentation/pages/chat_page.dart)

The AI maintains conversation context throughout the session, allowing for natural, contextual interactions while gathering all necessary information for accurate incident reporting.