# Welcome to BigBlueButton Tablet app 👋

BigBlueButton normally runs in a web browser. However, on iOS, browser-based screen sharing is not supported due to system limitations. This app solves that by embedding BigBlueButton in a native webview, allowing you to **share your screen on iOS devices**—something not possible with Safari or other browsers.

In addition to screen sharing, the app also provides **improved background audio support**, enhancing the overall meeting experience.

> **Note:** Although the app works on mobile phones, it is primarily optimized for tablets. Because it uses a webview to render the BigBlueButton interface, a device with a **strong CPU** is recommended for best performance.

## Use the app

The app is available on Apple App Store.

## Run from source

1. Ensure you are not using latest Xcode

Cocoa pods was not working with latest Xcode.
We downgrade it to 16.0 to get it working.
([Details](https://github.com/CocoaPods/CocoaPods/issues/12794))

2. Install ios dependencies

```bash
cd ios
pod install
```

3. Open the project in Xcode

```bash
open ios/bigbluebuttontablet.xcworkspace
```


4. Install javascript

   ```bash
   npm install
   ```

5. Start the app

   ```bash
   npx expo start
   ```

