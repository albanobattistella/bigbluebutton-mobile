# BigBlueButton Mobile 👋

A native iOS/Android app that brings **screen sharing capabilities** to BigBlueButton on iOS devices—a feature impossible to achieve in Safari or other iOS browsers due to platform limitations.

## ✨ Features

- **iOS Screen Sharing**: Share your screen in BigBlueButton meetings on iPad/iPhone
- **Background Audio Support**: Improved audio handling when app is in background
- **Native WebView**: Embedded BigBlueButton interface with native iOS controls
- **Multi-language Support**: English, Portuguese (Brazil), and German
- **Debug Tools**: Built-in logging and debugging popup for troubleshooting

> **Note:** While the app works on phones, it is primarily optimized for **tablets**. A device with a strong CPU is recommended for optimal performance.

## 📱 Download

The app is available on the Apple App Store as **BigBlueButton**.

## 🚀 Getting Started

### Prerequisites

- **Node.js** (v16 or higher)
- **npm** or **yarn**
- **Xcode 16.0** (⚠️ **NOT the latest version** - see note below)
- **CocoaPods** (for iOS dependencies)
- iOS device or simulator for testing

### ⚠️ Important: Xcode Version

**Do NOT use the latest Xcode.** Due to CocoaPods compatibility issues, you must use **Xcode 16.0 or lower**.

CocoaPods does not work with the latest Xcode versions. [See issue details](https://github.com/CocoaPods/CocoaPods/issues/12794)

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd bigbluebutton-mobile
   ```

2. **Install JavaScript dependencies**

   ```bash
   npm install
   ```

3. **Install iOS native dependencies**

   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Start the development server**

   ```bash
   npx expo start
   ```

5. **Run on iOS**

   ```bash
   npm run ios
   ```

   Or open in Xcode:
   ```bash
   open ios/bigbluebuttontablet.xcworkspace
   ```

   ⚠️ **Important:** Always open the `.xcworkspace` file, NOT the `.xcodeproj` file.

### Running on Android

```bash
npm run android
```

> **Note:** Screen sharing is currently only implemented for iOS.

## 🛠️ Development

### Project Structure

```
app/                      # Main application code
├── methods/              # Screen share method wrappers
├── events/               # Native event handlers
├── webview/              # WebView message handling
├── native-components/    # React Native bridges
└── MeetingWebView.tsx    # Main WebView component

components/               # Reusable UI components
i18n/                     # Internationalization files
├── locales/              # Translation files (en, pt-BR, de)
└── index.ts              # i18n configuration

ios/                      # Native iOS code
├── ScreenSharing/        # WebRTC screen share implementation
└── ReactExported/        # React Native native modules

android/                  # Native Android code
```

### Key Technologies

- **React Native** with Expo
- **Expo Router** for file-based navigation
- **TypeScript** with strict mode
- **WebRTC** (iOS) for screen sharing
- **react-i18next** for internationalization
- **React Native WebView** for embedding BigBlueButton

### Available Scripts

```bash
npm start              # Start Expo development server
npm run ios            # Run on iOS simulator
npm run android        # Run on Android emulator
npm run lint           # Run ESLint
npx expo start         # Alternative way to start dev server
```

## 🌍 Internationalization (i18n)

This project uses [react-i18next](https://react.i18next.com/), [i18next](https://www.i18next.com/), and [expo-localization](https://docs.expo.dev/versions/latest/sdk/localization/) for internationalization.

### Supported Languages

- **English** (en)
- **Portuguese (Brazil)** (pt-BR)
- **German** (de)

### Adding New Languages

1. Create a new translation file in `i18n/locales/<language-code>/translation.json`
2. Add the language to `i18n/index.ts`:
   ```typescript
   import translationNewLang from './locales/<language-code>/translation.json';

   const resources = {
     // ...existing languages
     '<language-code>': { translation: translationNewLang },
   };
   ```
3. Add the language option to the Picker in `app/_layout.tsx`

## 🐛 Debugging

The app includes a built-in debug popup accessible by tapping the status text in the toolbar:

- **App Logs**: Native-side logs from iOS/Android
- **Web Logs**: Console logs from the BigBlueButton WebView
- **Copy/Clear**: Actions for each log type

WebView debugging is enabled by default. For Safari debugging on iOS, connect your device and use Safari's Developer menu.

## 🏗️ Architecture

### Screen Sharing Flow (iOS)

1. User clicks screen share in WebView
2. WebView sends message to React Native
3. React Native calls native iOS module
4. iOS displays system broadcast picker
5. User confirms → WebRTC connection established
6. Broadcast extension captures frames
7. Frames sent via WebRTC to BigBlueButton server

The implementation uses:
- iOS Broadcast Upload Extension
- WebRTC for media streaming
- Inter-process communication via UserDefaults (app group)
- Background audio to keep app active during sharing

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

- Follow the existing code style
- Run `npm run lint` before committing
- Test on both iOS simulators and physical devices
- Update i18n files if you add user-facing text
- Document any iOS-specific or Android-specific code

## 📄 License

[Add your license information here]

## 💬 Support

For issues and questions:
- Create an issue in this repository
- Check existing issues for similar problems

## 🙏 Acknowledgments

Built with [BigBlueButton](https://bigbluebutton.org/) - an open-source web conferencing system.

---

Made with ❤️ using Expo and React Native

