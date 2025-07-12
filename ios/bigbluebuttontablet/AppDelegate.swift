import Expo
import React
import ReactAppDependencyProvider
import WebKit
import AVFoundation
import ReplayKit

/// Main app delegate handling app lifecycle, Expo + React Native setup,
/// screen sharing initialization, and heartbeat signaling.
@UIApplicationMain
public class AppDelegate: ExpoAppDelegate {
  
  // MARK: - Properties

  var window: UIWindow?
  private var pickerView: RPSystemBroadcastPickerView?
  var reactNativeDelegate: ExpoReactNativeFactoryDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  /// Shared instance for global access.
  static var shared: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
  }

  // MARK: - Application Lifecycle

  /// Main entry point after app launch.
  public override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    
    // React Native bootstrapping
    let delegate = ReactNativeDelegate()
    let factory = ExpoReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()
    
    reactNativeDelegate = delegate
    reactNativeFactory = factory
    bindReactNativeFactory(factory)

#if os(iOS) || os(tvOS)
    // Set up UIWindow and attach root React Native view
    window = UIWindow(frame: UIScreen.main.bounds)
    factory.startReactNative(
      withModuleName: "main",
      in: window,
      launchOptions: launchOptions
    )
#endif

    // Start frame polling logic for screen broadcasting
    ScreenSharePublisher.start()
    
    // Set up hidden system broadcast picker
    setupScreenShareButton()

    // Start heartbeat for companion processes
    startHeartbeat()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Deep Linking Support

  /// Handles links like myapp://somepath
  public override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options) ||
           RCTLinkingManager.application(app, open: url, options: options)
  }

  /// Handles universal links (e.g. website -> app)
  public override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let result = RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler) || result
  }

  // MARK: - Screen Share Picker Setup

  /// Initializes the hidden screen sharing button to trigger ReplayKit broadcast.
  private func setupScreenShareButton() {
    DispatchQueue.main.async {
      if self.pickerView == nil {
        let picker = RPSystemBroadcastPickerView(
          frame: CGRect(x: -1000, y: -1000, width: 50, height: 50)
        )
        picker.preferredExtension = "org.bigbluebutton.tablet.BigBlueButton-Screen-Share"
        picker.showsMicrophoneButton = false

        if let keyWindow = UIApplication.shared
          .connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .flatMap({ $0.windows })
          .first(where: { $0.isKeyWindow }) {
          keyWindow.addSubview(picker)
          self.pickerView = picker
        } else {
          print("Could not find key window")
        }
      }
    }
  }

  /// Programmatically triggers the screen share broadcast picker button.
  public func clickScreenShareButton() {
    DispatchQueue.main.async {
      if let button = self.pickerView?.subviews.first(where: { $0 is UIButton }) as? UIButton {
        button.sendActions(for: .touchUpInside)
      } else {
        print("Broadcast picker button not found")
      }
    }
  }

  // MARK: - Heartbeat

  /// Continuously updates a shared UserDefaults timestamp every second
  /// so external services (like the broadcast extension) know the app is alive.
  func startHeartbeat() {
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      let defaults = UserDefaults(suiteName: "group.org.bigbluebutton.tablet")!
      defaults.set(Date().timeIntervalSince1970, forKey: "mainAppHeartBeat")
    }
  }
}

// MARK: - React Native Bridge Delegate

/// Provides the correct JS bundle URL for development and production modes.
class ReactNativeDelegate: ExpoReactNativeFactoryDelegate {
  
  /// Returns the JS bundle URL for the React bridge.
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    return bridge.bundleURL ?? bundleURL()
  }

  /// Fallback for the JS bundle URL if not using the dev client.
  override func bundleURL() -> URL? {
#if DEBUG
    return RCTBundleURLProvider.sharedSettings().jsBundleURL(
      forBundleRoot: ".expo/.virtual-metro-entry"
    )
#else
    return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
