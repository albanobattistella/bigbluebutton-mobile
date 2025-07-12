import Expo
import React
import ReactAppDependencyProvider

@UIApplicationMain
public class AppDelegate: ExpoAppDelegate {
  var window: UIWindow?
  private var pickerView: RPSystemBroadcastPickerView?

  var reactNativeDelegate: ExpoReactNativeFactoryDelegate?
  var reactNativeFactory: RCTReactNativeFactory?
  
  static var shared: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
  }

  public override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()	
    let factory = ExpoReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = factory
    bindReactNativeFactory(factory)

#if os(iOS) || os(tvOS)
    window = UIWindow(frame: UIScreen.main.bounds)
    factory.startReactNative(
      withModuleName: "main",
      in: window,
      launchOptions: launchOptions)
#endif
    ScreenSharePublisher.start()
    
    setupScreenShareButton()
    
    startHeartbeat()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Linking API
  public override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options) || RCTLinkingManager.application(app, open: url, options: options)
  }

  // Universal Links
  public override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let result = RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler) || result
  }
  
  private func setupScreenShareButton() {
    DispatchQueue.main.async {
      if self.pickerView == nil {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: -1000, y: -1000, width: 50, height: 50))
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
          return
        }
      }
    }
  }
  
  public func clickScreenShareButton() {
    DispatchQueue.main.async {
      if let button = self.pickerView?.subviews.first(where: { $0 is UIButton }) as? UIButton {
        button.sendActions(for: .touchUpInside)
      } else {
        print("Broadcast picker button not found")
      }
    }
  }
  
  func startHeartbeat() {
      Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        let defaults = UserDefaults(suiteName: "group.org.bigbluebutton.tablet")!
        defaults.set(Date().timeIntervalSince1970, forKey: "mainAppHeartBeat")
      }
  }
}

class ReactNativeDelegate: ExpoReactNativeFactoryDelegate {
  // Extension point for config-plugins

  override func sourceURL(for bridge: RCTBridge) -> URL? {
    // needed to return the correct URL for expo-dev-client.
    bridge.bundleURL ?? bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: ".expo/.virtual-metro-entry")
#else
    return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
