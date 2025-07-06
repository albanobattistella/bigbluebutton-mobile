//
//  SampleHandler.swift
//  BigBlueButton Screen Share
//
//  Created by Tiago Daniel Jacobs on 22/05/25.
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
      print("Broadcast started")
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
      print("Broadcast paused")
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
      print("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
      print("Broadcast finished")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            print("Video sample")
            // Handle video sample buffer
            break
        case RPSampleBufferType.audioApp:
            print("App audio sample")
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
          print("Miv audio sample")
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            // Handle other sample buffer types
            fatalError("Unknown type of sample buffer")
        }
    }
}
