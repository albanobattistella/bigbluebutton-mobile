# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BigBlueButton Mobile is a React Native app built with Expo that embeds BigBlueButton in a native webview to enable iOS screen sharing—a feature unavailable in Safari and other iOS browsers. The app also provides improved background audio support for meetings.

**App Store Name:** BigBlueButton (in the context of mobile apps)

**Key Technologies:**
- Expo (v53) with React Native 0.79.2
- TypeScript with strict mode enabled
- Expo Router for navigation (file-based routing)
- React Native WebView for embedding BBB web interface
- Native iOS modules (Swift) for screen sharing via WebRTC
- i18next for internationalization (en, pt-BR, de)

## Development Commands

### Installation & Setup
```bash
# Install JavaScript dependencies
npm install

# Install iOS native dependencies (requires Xcode 16.0 or lower - NOT latest)
cd ios
pod install
cd ..
```

### Running the App
```bash
# Start Expo development server
npx expo start
# or
npm start

# Run on iOS simulator
npm run ios

# Run on Android
npm run android
```

### Code Quality
```bash
# Run ESLint
npm run lint
# or
npx expo lint
```

### Building
Open the Xcode workspace (NOT the .xcodeproj file):
```bash
open ios/bigbluebuttontablet.xcworkspace
```

## Important Development Notes

### Xcode Version Requirement
**Do NOT use the latest Xcode.** CocoaPods compatibility issues require Xcode 16.0 or lower. See: https://github.com/CocoaPods/CocoaPods/issues/12794

### App Group Configuration
The app uses the shared app group `group.org.bigbluebutton.tablet` for inter-process communication between the main app and the screen share broadcast extension.

### WebView Debugging
WebView debugging is enabled by default via `webviewDebuggingEnabled={true}` in MeetingWebView.tsx:180

## Architecture

### Core Components

**app/_layout.tsx**
- Root layout and entry point
- Handles language selection (Picker component)
- Manages meeting URL input and navigation to MeetingWebView
- Sets up theme provider and fonts

**app/MeetingWebView.tsx**
- Main WebView container that embeds BigBlueButton
- Manages WebView lifecycle (loading, loaded, error states)
- Implements debug popup with app and web logs
- Intercepts WebView console logs via injected JavaScript
- Routes WebView postMessage events to message handler
- Custom toolbar with close and refresh buttons
- Uses AppLogger singleton for native-side logging

**app/webview/message-handler.tsx**
- Central message dispatcher for WebView ↔ Native communication
- Handles method calls from WebView and converts to native promises
- Supported methods:
  - `initializeScreenShare` - Triggers iOS broadcast picker
  - `createScreenShareOffer` - Creates WebRTC offer
  - `setScreenShareRemoteSDP` - Sets remote SDP from server
  - `addRemoteIceCandidate` - Adds ICE candidates
  - `stopScreenShare` - Stops screen broadcast
- Uses sequence numbers to match requests with responses
- Injects JavaScript callbacks into WebView with results

### Screen Sharing Architecture

Screen sharing on iOS requires a complex architecture due to platform limitations:

**TypeScript/React Native Layer:**
- `app/methods/*.tsx` - JavaScript wrappers for each screen share method
- `app/native-components/BBBN_ScreenShareService.tsx` - React Native bridge to native module
- `app/native-messaging/emitter.tsx` - Event emitter for native → JS events
- `app/events/*.tsx` - Event handlers for broadcast lifecycle events

**iOS/Swift Layer:**
- `ios/ReactExported/ReactNativeScreenShareService.swift` - React Native module (@objc exposed)
  - Plays silent audio in loop to keep app active during screen share
  - Triggers system broadcast picker
  - Routes calls to ScreenBroadcasterService

- `ios/ScreenSharing/ScreenShareService.swift` - Core WebRTC service (singleton)
  - Manages WebRTC peer connection lifecycle
  - Creates/handles SDP offers and answers
  - Handles ICE candidate discovery and gathering
  - Pushes video frames to WebRTC stream
  - Implements ScreenShareWebRTCClientDelegate
  - Auto-reconnects on disconnection/failure

- `ios/ScreenSharing/WebRTC/ScreenShareWebRTCClient.swift` - WebRTC client wrapper
- `ios/BigBlueButton Screen Share/SampleHandler.swift` - Broadcast extension handler
- `ios/InterProcessCommunication/IPCFileManager.swift` - IPC between app and broadcast extension

**WebRTC Flow:**
1. User clicks share screen in WebView → WebView posts message
2. Message handler calls `initializeScreenShare()`
3. Native iOS shows broadcast picker dialog
4. User confirms → `onBroadcastStarted` event fires
5. WebView requests SDP offer via `createScreenShareOffer()`
6. WebRTC creates offer and returns to WebView
7. WebView sends offer to BBB server
8. Server responds with answer → `setScreenShareRemoteSDP()`
9. ICE candidates exchanged via `addRemoteIceCandidate()`
10. Frames captured by broadcast extension and pushed via WebRTC

### Internationalization (i18n)

**i18n/index.ts**
- Initializes i18next with react-i18next
- Loads translations from `i18n/locales/{en,pt-BR,de}/translation.json`
- Persists language selection to AsyncStorage
- Falls back to device locale, then 'en' if locale not supported

### Logging System

**components/AppLogger.ts**
- Singleton logger with observer pattern
- Maintains in-memory log array
- Notifies subscribers when logs change
- Used for displaying native-side logs in DebugPopup
- Supports info() and debug() levels

### Utilities

**components/DebugPopup.tsx**
- Draggable, resizable popup overlay
- Two tabs: App Logs and Web Logs
- Copy and clear functionality for each log type
- Triggered by tapping status text in toolbar

## File Structure Patterns

```
app/
  _layout.tsx              # Root layout
  MeetingWebView.tsx       # Main WebView component
  methods/                 # Screen share method wrappers
  events/                  # Native event handlers
  webview/                 # WebView message handling
  native-components/       # React Native native module interfaces
  native-messaging/        # Event emitter setup
components/                # Reusable UI components
constants/                 # Theme colors
hooks/                     # Custom React hooks
i18n/                      # Internationalization
  locales/                 # Translation files
ios/                       # Native iOS code
  ScreenSharing/           # WebRTC screen share implementation
  ReactExported/           # React Native bridges
  BigBlueButton Screen Share/  # Broadcast extension
android/                   # Native Android code (screen share not implemented)
```

## Testing Notes

The app is primarily designed for iOS tablets. While it runs on phones and Android, screen sharing functionality is iOS-specific and relies on the Broadcast Upload Extension.

## Known Issues & Workarounds

- CocoaPods requires Xcode 16.0 or lower (not latest version)
- Screen sharing keeps app active by playing silent audio in background
- Inter-process communication uses UserDefaults with shared app group
