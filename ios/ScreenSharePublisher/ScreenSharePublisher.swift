//
//  ScreenSharePublisher.swift
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs on 06/07/25.
//
final class ScreenSharePublisher {
  static private let queue = DispatchQueue(label: "hello.printer", qos: .utility)
  static private var timer: DispatchSourceTimer?

  static func start() {
    // 30 Hz  ≈  every 33 ms
    let t = DispatchSource.makeTimerSource(queue: queue)
    t.schedule(deadline: .now(),
               repeating: .milliseconds(33),
               leeway: .milliseconds(1))   // small leeway is fine for logs
    t.setEventHandler {
      let data = IPCCurrentVideoFrame.shared.get(count: 8)
      guard data != nil else { return }
      let value = data?.withUnsafeBytes {
          $0.load(as: Int.self)
      }
      print("Value: \(value ?? 0)")
    }
    t.resume()
    timer = t           // keep a strong reference so the timer isn’t cancelled
  }

  static func stop() { timer?.cancel(); timer = nil }
}

