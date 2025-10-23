//
//  ScreenSharePublisher.swift
//  bigbluebuttonmobile
//
//  Created by Tiago Daniel Jacobs, 2025
//

import Foundation
import UIKit          // For UIImage & UIActivityViewController
import CoreImage      // For CIImage & CIContext

/// A screen-sharing component that listens for new video frames,
/// detects the start of broadcasting, logs metadata, and relays frames
/// to the broadcasting service.
final class ScreenSharePublisher {
    
    // MARK: - Private State

    /// A dedicated queue for deserialization and processing tasks (low-priority utility queue).
    private static let queue = DispatchQueue(label: "hello.printer", qos: .utility)

    /// Shared timer for periodic frame polling.
    private static var timer: DispatchSourceTimer?

    /// Tracks if we’re actively broadcasting (i.e., received non-clean frames).
    /// On transition from `false → true`, "Broadcast started" is logged once.
    private static var broadcastActive = false

    // MARK: - Public API

    /// Starts the screen-share monitoring logic with a ~30Hz polling timer.
    static func start() {
        // Create the dispatch timer
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(
            deadline: .now(),
            repeating: .milliseconds(33),  // ≈ 30Hz
            leeway: .milliseconds(1)       // Slight flexibility is acceptable
        )
        
        // Reset shared frame memory and internal state
        IPCCurrentVideoFrame.shared.clear()
        broadcastActive = false

        // Define timer's work block
        t.setEventHandler {
            // 1️⃣ Attempt to fetch the latest frame data
            guard let data = IPCCurrentVideoFrame.shared.get() else {
                return  // No frame data yet
            }

            // 2️⃣ Determine if the buffer is clean (no visual change)
            let isClean = IPCCurrentVideoFrame.shared.isClean()

            // 3️⃣ Detect transition into broadcasting
            if !isClean && !broadcastActive {
                broadcastActive = true
                print("Broadcast started")
                ReactNativeEventEmitter.emitter.sendEvent(
                    withName: ReactNativeEventEmitter.EVENT.onBroadcastStarted.rawValue,
                    body: nil
                )
            } else if isClean && broadcastActive {
                // Reset state when returning to clean
                broadcastActive = false
            }

            // 4️⃣ Skip frame if there's no new content
            guard !isClean else {
                return
            }

            // 5️⃣ Attempt to deserialize the pixel buffer and log details
            do {
                // Destructure the returned tuple into buffer, orientation, and metadata
                let (buffer, orientation, header) = try deserializePixelBufferFull(data)

                // Extract and (optionally) log the height for diagnostics
                let height = CVPixelBufferGetHeight(buffer)
                // print("Frame height: \(height)")
                // print("Decoded timestamp: \(header.timestampNs)")

                // 6️⃣ Pass the frame to the broadcasting service
                ScreenBroadcasterService.shared.pushVideoFrame(
                    timeStampNs: header.timestampNs,
                    orientation: orientation,
                    imageBuffer: buffer
                )

            } catch {
                // Handle any deserialization error (with detailed message)
                print("Failed to deserialize pixel buffer – \(error)")
            }
        }

        // Start the timer and retain a reference to prevent deallocation
        t.resume()
        timer = t
    }

    /// Stops the polling and resets the broadcast state.
    static func stop() {
        timer?.cancel()
        timer = nil
        broadcastActive = false  // Clean up internal state
    }
}
