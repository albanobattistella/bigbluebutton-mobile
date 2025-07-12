//
//  ScreenShareService.swift
//
//  Created by Tiago Daniel Jacobs on 11/03/22.
//

import Foundation
import os
import AVFAudio

@objc(ScreenShareService)
class ScreenShareService: NSObject {
    // Logger (these messages are displayed in the console application)
    private var logger = os.Logger(subsystem: "BigBlueButtonTabletSDK", category: "ScreenShareServiceManager")
    var audioSession = AVAudioSession.sharedInstance()
    var player: AVAudioPlayer!
    
    // React native exposed method (called when user click the button to share screen)
    @objc func initializeScreenShare() -> Void {
        logger.info("initializeScreenShare")
        
        // Play audio in loop, to keep app active
        self.activeAudioSession(bool: true)
        let path = Bundle.main.path(forResource: "music2", ofType : "mp3")!
        let url = URL(fileURLWithPath : path)
        do {
            
            self.player = try AVAudioPlayer(contentsOf: url)
            self.player.play()
            self.playSoundInLoop()
        }
        catch {
            logger.error("Error to play audio = \(url)")
        }
 
        // Request the system broadcast
        logger.info("initializeScreenShare - requesting broadcast")
        AppDelegate.shared.clickScreenShareButton()
        
        let eventName = ReactNativeEventEmitter.EVENT.onBroadcastRequested.rawValue
        logger.info("initializeScreenShare - emitting event \(eventName)")
        ReactNativeEventEmitter.emitter.sendEvent(withName: eventName, body: nil);
      
        // Clear the current video frame, so the ScreenSharePublisher knows it's a new screenshare
        IPCCurrentVideoFrame.shared.clear()
    }
    
    // React native exposed method (called when user click the button to share screen)
    @objc func createScreenShareOffer(_ stunTurnJson:String) -> Void {
        logger.info("createScreenShareOffer \(stunTurnJson)")
        Task.init {
          let optionalSdp = await ScreenBroadcasterService.shared.createOffer()
          if(optionalSdp != nil){
              let sdp = optionalSdp!
              self.logger.info("Got SDP back from screenBroadcaster: \(sdp)")
              
              ReactNativeEventEmitter.emitter.sendEvent(withName: ReactNativeEventEmitter.EVENT.onScreenShareOfferCreated.rawValue, body: sdp)
          }
        }
    }
    
    @objc func setScreenShareRemoteSDP(_ remoteSDP:String) -> Void {
        logger.info("setScreenShareRemoteSDP call arrived on swift: \(remoteSDP)")
      
        Task.init {
          let optionalSdp = await ScreenBroadcasterService.shared.setRemoteSDP(remoteSDP: remoteSDP)
          ReactNativeEventEmitter.emitter.sendEvent(withName: ReactNativeEventEmitter.EVENT.onSetScreenShareRemoteSDPCompleted.rawValue, body: nil)
        }
        
    }
    
    
    @objc func addScreenShareRemoteIceCandidate(_ remoteCandidate:String) -> Void {
        logger.info("addScreenShareRemoteIceCandidate call arrived on swift: \(remoteCandidate)")
        // Send request of "add remote ICE candidate" to broadcast upload extension
        // TIP - the handling of this method response is done in observer6 of BigBlueButtonSDK class
        logger.info("addScreenShareRemoteIceCandidate - persisting information on UserDefaults")
//        BBBSharedData
//            .getUserDefaults(appGroupName: BigBlueButtonSDK.getAppGroupName())
//            .set(BBBSharedData.generatePayload(properties: [
//                "candidate": remoteCandidate
//            ]), forKey: BBBSharedData.SharedData.addScreenShareRemoteIceCandidate)
        
    }
    
    @objc func stopScreenShareBroadcastExtension() -> Void {
      let userDefaults = UserDefaults(suiteName: "group.org.bigbluebutton.tablet")
      userDefaults?.set(true, forKey: "stopBroadcast")
      userDefaults?.synchronize()
    }
  
    func activeAudioSession(bool BoolToActive: Bool){
        do{
            try audioSession.setActive(BoolToActive)
        }catch{
            logger.error("Error to change status of audioSession")
        }
    }
    
    //This method prevents the sound that keeps the app active in the background
    func playSoundInLoop(){
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3000) {
            self.logger.info("restarting music")
            self.player.currentTime = 0.1;
            self.playSoundInLoop()//recursive call
        }
        
    }
    
}

