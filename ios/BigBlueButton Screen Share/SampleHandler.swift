//
//  SampleHandler.swift
//  BigBlueButton Screen Share
//
//  Created by Tiago Daniel Jacobs on 22/05/25.
//

// Debug flags
struct DebugFlags {
    static var stopTimer   = false
    static var videoFrames = false
    static var audioApp    = false
    static var audioMic    = false
}

@inline(__always)
func dlog(_ enabled: @autoclosure () -> Bool, _ message: @autoclosure () -> String) {
    if enabled() { print(message()) }
}

class SampleHandler: RPBroadcastSampleHandler {

    private var stopMonitorTimer: DispatchSourceTimer?

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        dlog(DebugFlags.stopTimer, "Broadcast started")
        IPCCurrentVideoFrame.shared.clear()

        let queue = DispatchQueue(label: "org.bigbluebutton.tablet.stop-monitor")
        stopMonitorTimer = DispatchSource.makeTimerSource(queue: queue)
        stopMonitorTimer?.schedule(deadline: .now() + 1, repeating: 1)

        stopMonitorTimer?.setEventHandler { [weak self] in
            guard let strongSelf = self else {
                dlog(DebugFlags.stopTimer, "stop timer – strongSelf nil")
                self?.stopMonitorTimer?.cancel()
                return
            }
            dlog(DebugFlags.stopTimer, "stop timer – running")

            let userDefaults = UserDefaults(suiteName: "group.org.bigbluebutton.tablet")

            if userDefaults?.bool(forKey: "stopBroadcast") == true {
                dlog(DebugFlags.stopTimer, "stop timer – stopBroadcast=true")
                finishBroadcastGracefully(strongSelf)
                userDefaults?.set(false, forKey: "stopBroadcast")
                userDefaults?.synchronize()
                strongSelf.stopMonitorTimer?.cancel()
                return
            } else {
                dlog(DebugFlags.stopTimer, "stop timer – stopBroadcast=false")
            }

            if let last = userDefaults?.double(forKey: "mainAppHeartBeat") {
                if last > 0 {
                    if Date().timeIntervalSince1970 - last > 3 {
                        dlog(DebugFlags.stopTimer, "stop timer – heart stopped beating (last = \(Date(timeIntervalSince1970: last)))")
                        // finishBroadcastGracefully(strongSelf)
                    } else {
                        dlog(DebugFlags.stopTimer, "stop timer – heart is still beating")
                    }
                } else {
                    dlog(DebugFlags.stopTimer, "stop timer – no heart beat yet (last = 0)")
                }
            } else {
                dlog(DebugFlags.stopTimer, "stop timer – no heart beat yet")
            }
        }

        stopMonitorTimer?.resume()
    }

    override func broadcastFinished() {
        stopMonitorTimer?.cancel()
        stopMonitorTimer = nil
        dlog(DebugFlags.stopTimer, "Broadcast finished")
    }

    override func broadcastPaused() {
        dlog(DebugFlags.stopTimer, "Broadcast paused")
    }

    override func broadcastResumed() {
        dlog(DebugFlags.stopTimer, "Broadcast resumed")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            dlog(DebugFlags.videoFrames, "Video sample – begin")

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                dlog(DebugFlags.videoFrames, "Video sample – skip 1")
                return
            }

            var orientation = CGImagePropertyOrientation.up
            if let o = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
                orientation = CGImagePropertyOrientation(rawValue: o.uint32Value) ?? .up
            }
          
          let timestampNs = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000)
          print("Encoded timestamp: \(timestampNs)")

          guard let data = serializePixelBufferFull(pixelBuffer: pixelBuffer, orientation: orientation, timestampNs:timestampNs) else {
                dlog(DebugFlags.videoFrames, "Video sample – skip 2")
                return
            }

            IPCCurrentVideoFrame.shared.set(data)
            dlog(DebugFlags.videoFrames, "Video sample – end")

        case .audioApp:
            dlog(DebugFlags.audioApp, "App audio sample")

        case .audioMic:
            dlog(DebugFlags.audioMic, "Mic audio sample")

        @unknown default:
            fatalError("Unknown type of sample buffer")
        }
    }
}
