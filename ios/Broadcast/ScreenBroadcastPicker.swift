//
//  ScreenBroadcastPicker.swift
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs on 06/07/25.
//
import Foundation
import ReplayKit

@objc(ScreenBroadcastPicker)
class ScreenBroadcastPicker: NSObject	 {

  private var pickerView: RPSystemBroadcastPickerView?

  static func moduleName() -> String! {
    return "ScreenBroadcastPicker"
  }

  static func requiresMainQueueSetup() -> Bool {
    return true
  }

  @objc func start(_ resolve: @escaping RCTPromiseResolveBlock,
                   rejecter reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      if self.pickerView == nil {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: -1000, y: -1000, width: 50, height: 50))
        picker.preferredExtension = "com.bigbluebuttontablet.ShareSetupUI"  // <- match your extension’s bundle ID
        picker.showsMicrophoneButton = false

        if let keyWindow = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
          keyWindow.addSubview(picker)
          self.pickerView = picker
        } else {
          reject("no_window", "Could not find key window", nil)
          return
        }
      }

      if let button = self.pickerView?.subviews.first(where: { $0 is UIButton }) as? UIButton {
        button.sendActions(for: .touchUpInside)
        resolve(nil)
      } else {
        reject("no_button", "Broadcast picker button not found", nil)
      }
    }
  }

  @objc func stop(_ resolve: @escaping RCTPromiseResolveBlock,
                  rejecter reject: @escaping RCTPromiseRejectBlock) {

    guard RPScreenRecorder.shared().isRecording else {
      resolve(nil)
      return
    }

    /*// 1. Pick a temporary filename for the movie
    let tmp = FileManager.default.temporaryDirectory
    let outputURL = tmp.appendingPathComponent(
                      "screenRecording-\(UUID().uuidString).mp4")

    if #available(iOS 16.0, *) {
      // iOS 11+ overload: ONE parameter (Error?)
     RPScreenRecorder.shared().stopRecording(withOutput: outputURL, completionHandler: { error in
        if let err = error {
          reject("stop_error", err.localizedDescription, err)
        } else {
          resolve(nil)
        }
      })

    } else {
      // Pre-iOS 11 overload: TWO parameters (RPPreviewViewController?, Error?)
      RPScreenRecorder.shared().stopRecording { _, error in
        if let err = error {
          reject("stop_error", err.localizedDescription, err)
        } else {
          resolve(nil)
        }
      }
    }*/
  }




}
