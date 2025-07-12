//
//  ScreenSharePublisher.swift
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs on 06/07/25.
//  Updated: 09/07/25 — detect first dirty frame, log “Broadcast started”.
//

import Foundation
import UIKit          // for UIImage & UIActivityViewController
import CoreImage      // for CIImage & CIContext

/// Publishes screen-share frames and logs their height. Each time it logs, it also snapshots the frame
/// to a PNG file in the temporary directory and presents a share-sheet so the user can save/export it.
final class ScreenSharePublisher {
    // Worker queue for deserialization + logging (utility QoS is fine)
    private static let queue = DispatchQueue(label: "hello.printer", qos: .utility)
    private static var timer: DispatchSourceTimer?
    /// Tracks whether we’re currently in a “broadcasting” state (i.e. frames are non-clean).
    /// When this flips from `false → true`, we print **Broadcast started** exactly once.
    private static var broadcastActive = false

    /// Kick-off a 30 Hz timer that processes incoming frames from IPC.
    static func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(),
                   repeating: .milliseconds(33),   // ≈ 30 Hz
                   leeway: .milliseconds(1))        // small leeway is fine for logs
      
        IPCCurrentVideoFrame.shared.clear()
        broadcastActive = false                    // reset state on every start

        t.setEventHandler {
            // 1️⃣  Grab the bytes (may be nil if producer hasn’t written yet)
            guard let data = IPCCurrentVideoFrame.shared.get() else { return }
            
            // 2️⃣  Determine cleanliness *before* any early return
            let isClean = IPCCurrentVideoFrame.shared.isClean()

            // Edge-detection: clean → dirty transition?
            if !isClean && !broadcastActive {
                broadcastActive = true
                print("Broadcast started")
                ReactNativeEventEmitter.emitter.sendEvent(withName: ReactNativeEventEmitter.EVENT.onBroadcastStarted.rawValue, body: nil)
            } else if isClean && broadcastActive {
                // We’ve gone back to clean; reset so the next dirty frame can trigger again.
                broadcastActive = false
            }
            
            // Short-circuit if the buffer is clean
            guard !isClean else {
                // print("Skipping frame decode as the shared memory area is clean")
                return
            }

            do {
                // (buffer, orientation) pattern-matches the tuple being returned
                let (buffer, orientation, header) = try deserializePixelBufferFull(data)

                // 3️⃣  Log the frame height
                let height = CVPixelBufferGetHeight(buffer)
                // print("Height: \(height)")
              
              print("Decoded timestamp: \(header.timestampNs)")

              ScreenBroadcasterService.shared.pushVideoFrame(
                timeStampNs: header.timestampNs,
                orientation: orientation,
                imageBuffer: buffer
              )

            } catch {
                // Every early-exit in the helper now throws a descriptive PBDeserializationError
                print("Failed to deserialize pixel buffer – \(error)")
            }
        }

        t.resume()
        timer = t   // keep a strong reference so the timer isn’t cancelled
    }

    static func stop() {
        timer?.cancel()
        timer = nil
        broadcastActive = false    // be tidy for the next start()
    }

}
