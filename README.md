# Welcome to BigBlueButton Tablet app 👋

BigBlueButton normally runs in a web browser. However, on iOS, browser-based screen sharing is not supported due to system limitations. This app solves that by embedding BigBlueButton in a native webview, allowing you to **share your screen on iOS devices**—something not possible with Safari or other browsers.

In addition to screen sharing, the app also provides **improved background audio support**, enhancing the overall meeting experience.

> **Note:** Although the app works on mobile phones, it is primarily optimized for tablets. Because it uses a webview to render the BigBlueButton interface, a device with a **strong CPU** is recommended for best performance.

## Use the app

The app is available on Apple App Store.

## Run from source

1. Install dependencies

   ```bash
   npm install
   ```

2. Start the app

   ```bash
   npx expo start
   ```

In the output, you'll find options to open the app in a

- [development build](https://docs.expo.dev/develop/development-builds/introduction/)
- [Android emulator](https://docs.expo.dev/workflow/android-studio-emulator/)
- [iOS simulator](https://docs.expo.dev/workflow/ios-simulator/)
- [Expo Go](https://expo.dev/go), a limited sandbox for trying out app development with Expo

You can start developing by editing the files inside the **app** directory. This project uses [file-based routing](https://docs.expo.dev/router/introduction).

## Get a fresh project

When you're ready, run:

```bash
npm run reset-project
```

This command will move the starter code to the **app-example** directory and create a blank **app** directory where you can start developing.

## Learn more

To learn more about developing your project with Expo, look at the following resources:

- [Expo documentation](https://docs.expo.dev/): Learn fundamentals, or go into advanced topics with our [guides](https://docs.expo.dev/guides).
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/): Follow a step-by-step tutorial where you'll create a project that runs on Android, iOS, and the web.

## Join the community

Join our community of developers creating universal apps.

- [Expo on GitHub](https://github.com/expo/expo): View our open source platform and contribute.
- [Discord community](https://chat.expo.dev): Chat with Expo users and ask questions.
