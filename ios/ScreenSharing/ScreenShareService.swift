//
//  ScreenBroadcaster.swift
//
//  Created by Tiago Daniel Jacobs, 2025
//

import os
import WebRTC
import UIKit

/// Service responsible for capturing and broadcasting screen share frames using WebRTC.
/// Implemented as a singleton.
open class ScreenBroadcasterService {
    
    // MARK: - Singleton
    
    /// Shared instance of the broadcaster.
    public static let shared = ScreenBroadcasterService()
    
    // MARK: - Properties

    /// Logger for internal diagnostics.
    private var logger = os.Logger(subsystem: "BigBlueButtonTabletSDK", category: "ScreenBroadcasterService")
    
    /// The internal WebRTC client for media negotiation and frame pushing.
    private var webRTCClient: ScreenShareWebRTCClient
    
    /// App Group identifier (used for shared container storage, if needed).
    private var appGroupName: String = "group.org.bigbluebutton.tablet"
    
    /// JSON encoder used for serializing signaling data.
    private let encoder = JSONEncoder()
    
    /// Flag indicating whether the WebRTC connection has been successfully established.
    public var isConnected: Bool = false

    // MARK: - Initialization

    /// Initializes the service with default STUN servers and sets itself as the WebRTC delegate.
    private init() {
        self.webRTCClient = ScreenShareWebRTCClient(iceServers: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ])
        self.webRTCClient.delegate = self
    }
  
    private func reInit() {
        self.webRTCClient = ScreenShareWebRTCClient(iceServers: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ])
        self.webRTCClient.delegate = self
    }

    // MARK: - WebRTC Signaling Methods
    
    /// Creates an SDP offer to initiate screen-sharing connection.
    public func createOffer() async -> String? {
        do {
            let rtcSessionDescription = try await self.webRTCClient.offer()
            return rtcSessionDescription.sdp
        } catch {
            logger.error("Error on webRTCClient.offer")
            return nil
        }
    }
    
    /// Sets the remote SDP (received from the server).
    public func setRemoteSDP(remoteSDP: String) async -> Bool {
        do {
            try await self.webRTCClient.setRemoteSDP(remoteSDP: remoteSDP)
            return true
        } catch {
            return false
        }
    }
    
    /// Adds a remote ICE candidate received from the server.
    public func addRemoteCandidate(remoteCandidate: IceCandidate) async -> Bool {
        do {
            try await self.webRTCClient.setRemoteCandidate(remoteIceCandidate: remoteCandidate)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Video Frame Pushing

    /// Pushes a screen-captured video frame to the WebRTC stream.
    public func pushVideoFrame(
        timeStampNs: Int64,
        orientation: CGImagePropertyOrientation,
        imageBuffer: CVImageBuffer
    ) {
        // Ensure we are connected before pushing frames
        guard isConnected else {
            logger.info("Ignoring pushVideoFrame - not connected")
            return
        }

        // Determine proper rotation for the frame based on image orientation
        var rotationFrame: RTCVideoRotation = ._0
        switch orientation.rawValue {
        case 6: rotationFrame = ._270    // Right
        case 8: rotationFrame = ._90     // Left
        default: break
        }

        // Wrap the image buffer in a WebRTC pixel buffer
        let rtcPixlBuffer = RTCCVPixelBuffer(pixelBuffer: imageBuffer)

        // Set ratio if it's not already defined
        if !webRTCClient.getIsRatioDefined() {
            webRTCClient.setRatio(originalWidth: rtcPixlBuffer.width, originalHeight: rtcPixlBuffer.height)
        }

        // Create a video frame and push it to the WebRTC client
        let rtcVideoFrame = RTCVideoFrame(
            buffer: rtcPixlBuffer,
            rotation: rotationFrame,
            timeStampNs: timeStampNs
        )
        webRTCClient.push(videoFrame: rtcVideoFrame)
    }
}

// MARK: - WebRTC Delegate Implementation

extension ScreenBroadcasterService: ScreenShareWebRTCClientDelegate {
    
    /// Called when a new local ICE candidate is discovered.
    public func webRTCClient(_ client: ScreenShareWebRTCClient, didDiscoverLocalCandidate rtcIceCandidate: RTCIceCandidate) {
        do {
            let iceCandidate = IceCandidate(from: rtcIceCandidate)
            let iceCandidateAsJsonData = try encoder.encode(iceCandidate)
            let iceCandidateAsJsonString = String(decoding: iceCandidateAsJsonData, as: UTF8.self)

            // Uncomment and use if shared data needs to be communicated to another process
            /*
            BBBSharedData
                .getUserDefaults(appGroupName: self.appGroupName)
                .set(BBBSharedData.generatePayload(properties: [
                    "iceJson": iceCandidateAsJsonString
                ]), forKey: BBBSharedData.SharedData.onScreenShareLocalIceCandidate)
            */
        } catch {
            logger.error("Error handling ICE candidate")
        }
    }
    
    /// Called when ICE connection state changes.
    public func webRTCClient(_ client: ScreenShareWebRTCClient, didChangeIceConnectionState state: RTCIceConnectionState) {
        switch state {
        case .connected:
            logger.info("didChangeConnectionState -> connected")
        case .completed:
            logger.info("didChangeConnectionState -> completed")
        case .disconnected, .failed, .closed:
          logger.info("didChangeConnectionState -> \(state.rawValue) - cleaning up")
            isConnected = false
            disconnect()
            reInit()
        default:
            break
        }
    }
    
    public func disconnect() {
        logger.info("Cleaning up ScreenBroadcasterService...")
        isConnected = false
        webRTCClient.close()
    }
    
    /// Called when ICE gathering state changes.
    public func webRTCClient(_ client: ScreenShareWebRTCClient, didChangeIceGatheringState state: RTCIceGatheringState) {
        switch state {
        case .new:
            logger.info("didChangeGatheringState -> new")
        case .gathering:
            logger.info("didChangeGatheringState -> gathering")
        case .complete:
            logger.info("didChangeGatheringState -> complete")
        @unknown default:
            logger.error("Unknown gathering state: \(state.rawValue)")
        }
    }
    
    /// Called when signaling state changes.
    public func webRTCClient(_ client: ScreenShareWebRTCClient, didChangeSignalingState state: RTCSignalingState) {
        var stateString = ""

        switch state {
        case .haveLocalOffer:
            logger.info("peerConnection new signaling state -> haveLocalOffer")
            stateString = "have-local-offer"
        case .haveLocalPrAnswer:
            logger.info("peerConnection new signaling state -> haveLocalPrAnswer")
            stateString = "have-local-pranswer"
        case .haveRemoteOffer:
            logger.info("peerConnection new signaling state -> haveRemoteOffer")
            stateString = "have-remote-offer"
        case .haveRemotePrAnswer:
            logger.info("peerConnection new signaling state -> haveRemotePrAnswer")
            stateString = "have-remote-pranswer"
        case .stable:
            logger.info("peerConnection new signaling state -> stable")
            stateString = "stable"
        case .closed:
            logger.info("peerConnection new signaling state -> closed")
            stateString = "closed"
        default:
            logger.error("peerConnection new signaling state -> UNKNOWN")
        }

        // Connection considered active after first signaling state change
        isConnected = true

        // Uncomment if shared data needs to be updated externally
        /*
        BBBSharedData
            .getUserDefaults(appGroupName: self.appGroupName)
            .set(BBBSharedData.generatePayload(properties: [
                "newState": stateString
            ]), forKey: BBBSharedData.SharedData.onScreenShareSignalingStateChange)
        */
    }
}
