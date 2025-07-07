//
//  ScreenSharePublisher.swift
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs on 06/07/25.
//  Updated: 06/07/25 — capture each frame as PNG when logging height and present a share‑sheet so the user can save it.
//

import Foundation
import UIKit          // for UIImage & UIActivityViewController
import CoreImage      // for CIImage & CIContext

/// Publishes screen‑share frames and logs their height. Each time it logs, it also snapshots the frame
/// to a PNG file in the temporary directory and presents a share‑sheet so the user can save/export it.
final class ScreenSharePublisher {
    // Worker queue for deserialization + logging (utility QoS is fine)
    private static let queue = DispatchQueue(label: "hello.printer", qos: .utility)
    private static var timer: DispatchSourceTimer?

    /// Kick‑off a 30 Hz timer that processes incoming frames from IPC.
    static func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(),
                   repeating: .milliseconds(33),   // ≈ 30 Hz
                   leeway: .milliseconds(1))        // small leeway is fine for logs
      
        IPCCurrentVideoFrame.shared.clear()

        t.setEventHandler {
            guard let data = IPCCurrentVideoFrame.shared.get() else { return }

            do {
                // (buffer, orientation) pattern‑matches the tuple being returned
                let (buffer, _) = try deserializePixelBufferFull(data)

                // 1️⃣  Log the frame height
                let height = CVPixelBufferGetHeight(buffer)
                print("Height: \(height)")

                // 2️⃣  Export the frame to PNG & offer it via a share‑sheet
                self.offerToSave(pixelBuffer: buffer)

            } catch {
                // Every early‑exit in the helper now throws a descriptive PBDeserializationError
                print("Failed to deserialize pixel buffer – \(error)")
            }
        }

        t.resume()
        timer = t   // keep a strong reference so the timer isn’t cancelled
    }

    static func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: – Private helpers

    /// Converts a CVPixelBuffer into a PNG file (in /tmp), then presents a share‑sheet so the user can save it.
    private static func offerToSave(pixelBuffer: CVPixelBuffer) {
        // Convert pixel‑buffer → CIImage → CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("[ScreenSharePublisher] Couldn’t create CGImage from CIImage")
            return
        }

        // Encode as PNG using UIImage for convenience
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else {
            print("[ScreenSharePublisher] Failed to create PNG data")
            return
        }

        // Write to a unique file in the temporary directory
        let filename = "frame-\(Int(Date().timeIntervalSince1970)).png"
        let fileURL  = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try pngData.write(to: fileURL, options: .atomic)
            print("[ScreenSharePublisher] PNG written to \(fileURL.path)")
        } catch {
            print("[ScreenSharePublisher] Failed to write PNG: \(error)")
            return
        }

        // Present a share‑sheet on the main thread so the user can save/share the PNG.
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1) // iPad safety

            // Find a suitable presenter (key window’s root VC)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                print("[ScreenSharePublisher] Could not find root view‑controller to present share‑sheet")
                return
            }

            rootVC.present(activityVC, animated: true)
        }
    }
}
