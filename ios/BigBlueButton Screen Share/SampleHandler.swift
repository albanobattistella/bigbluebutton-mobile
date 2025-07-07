//
//  SampleHandler.swift
//  BigBlueButton Screen Share
//
//  Created by Tiago Daniel Jacobs on 22/05/25.
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast.
        // Setup info from the UI extension can be supplied but is optional.
        print("Broadcast started")
        IPCCurrentVideoFrame.shared.clear()
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast.
        // Samples will stop being delivered.
        print("Broadcast paused")
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast.
        // Sample delivery will resume.
        print("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        print("Broadcast finished")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            print("Video sample - begin")
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Video sample - skip 1")
                return
            }
            
            var orientation = CGImagePropertyOrientation.up
            if let o = CMGetAttachment(
                sampleBuffer,
                key: RPVideoSampleOrientationKey as CFString,
                attachmentModeOut: nil
            ) as? NSNumber {
                orientation = CGImagePropertyOrientation(rawValue: o.uint32Value) ?? .up
            }
            
            guard let data = serializePixelBufferFull(pixelBuffer, orientation: orientation) else {
                print("Video sample - skip 2")
                return
            }
            
            IPCCurrentVideoFrame.shared.set(data)
            print("Video sample - end")
            
        case .audioApp:
            print("App audio sample")
            // Handle audio sample buffer for app audio
            
        case .audioMic:
            print("Mic audio sample")
            // Handle audio sample buffer for mic audio
            
        @unknown default:
            fatalError("Unknown type of sample buffer")
        }
    }
}
