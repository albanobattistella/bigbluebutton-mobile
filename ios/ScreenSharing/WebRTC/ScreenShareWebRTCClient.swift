//
//  ScreenShareWebRTCClient.swift
//  WebRTC
//  Created by Tiago Daniel Jacobs, 2025
//

import Foundation
import WebRTC
import os

// MARK: - Delegate Protocol

/// Delegate to receive WebRTC events for signaling, ICE, and connection lifecycle.
public protocol ScreenShareWebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: ScreenShareWebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: ScreenShareWebRTCClient, didChangeIceConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: ScreenShareWebRTCClient, didChangeIceGatheringState state: RTCIceGatheringState)
    func webRTCClient(_ client: ScreenShareWebRTCClient, didChangeSignalingState state: RTCSignalingState)
}

// MARK: - WebRTC Client Class

/// Manages WebRTC peer connection, video track setup, and signaling for screen share publishing.
open class ScreenShareWebRTCClient: NSObject {
    
    private var logger = os.Logger(subsystem: "BigBlueButtonTabletSDK", category: "WebRTCClient")

    /// Shared PeerConnectionFactory used to create tracks and peer connections.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        encoderFactory.preferredCodec = RTCVideoCodecInfo(name: kRTCVideoCodecVp8Name)
        return RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }()
    
    // MARK: - Properties

    public weak var delegate: ScreenShareWebRTCClientDelegate?
    private let peerConnection: RTCPeerConnection
    private let rtcAudioSession = RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "audio")
    private let mediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueFalse,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse
    ]
    
    private var videoSource: RTCVideoSource?
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var isRatioDefined = false

    // MARK: - Initializer

    /// Prevent direct use. Always use designated init with iceServers.
    @available(*, unavailable)
    override init() {
        fatalError("init is unavailable. Use init(iceServers:) instead.")
    }

    /// Constructs the client and sets up the peer connection with STUN config.
    public required init(iceServers: [String]) {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherOnce
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )

        guard let pc = Self.factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            fatalError("Failed to create RTCPeerConnection")
        }

        self.peerConnection = pc
        super.init()

        createMediaSenders()
        self.peerConnection.delegate = self
    }

    // MARK: - Signaling

    /// Generates a WebRTC offer and sets it as the local SDP.
    public func offer() async throws -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains, optionalConstraints: nil)
        let sdp = try await peerConnection.offer(for: constraints)
        try await peerConnection.setLocalDescription(sdp)
        return sdp
    }

    /// Sets the received remote SDP answer.
    public func setRemoteSDP(remoteSDP: String) async throws {
        let desc = RTCSessionDescription(type: .answer, sdp: remoteSDP)
        try await peerConnection.setRemoteDescription(desc)
    }

    /// Adds a remote ICE candidate to the peer connection.
    public func setRemoteCandidate(remoteIceCandidate: IceCandidate) async throws {
        let rtcCandidate = RTCIceCandidate(
            sdp: remoteIceCandidate.candidate,
            sdpMLineIndex: remoteIceCandidate.sdpMLineIndex,
            sdpMid: remoteIceCandidate.sdpMid
        )
        try await peerConnection.add(rtcCandidate)
    }

    /// Adds a remote ICE candidate with a completion handler (legacy fallback).
    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        peerConnection.add(remoteCandidate, completionHandler: completion)
    }

    // MARK: - Video Frame Ingestion

    /// Pushes a raw `RTCVideoFrame` into the video capturer pipeline.
    public func push(videoFrame: RTCVideoFrame) {
        guard let source = videoSource, let capturer = videoCapturer else { return }
        source.capturer(capturer, didCapture: videoFrame)
        // print("RTCVideoFrame pushed to server.")
    }

    // MARK: - Media Setup

    /// Creates and registers a video track as a media sender.
    private func createMediaSenders() {
        let streamId = "stream"
        let videoTrack = createVideoTrack()
        self.localVideoTrack = videoTrack
        peerConnection.add(videoTrack, streamIds: [streamId])
    }

    /// Instantiates a screen-cast video track and binds it to the capturer.
    private func createVideoTrack() -> RTCVideoTrack {
        videoSource = Self.factory.videoSource(forScreenCast: true)
        videoCapturer = RTCVideoCapturer(delegate: videoSource!)
        let track = Self.factory.videoTrack(with: videoSource!, trackId: "video0")
        track.isEnabled = true
        return track
    }

    // MARK: - Resolution Configuration

    /// Sets the output format (width/height/fps) for the video source.
    public func setRatio(originalWidth: Int32, originalHeight: Int32) {
        videoSource?.adaptOutputFormat(toWidth: originalWidth, height: originalHeight, fps: 30)
        isRatioDefined = true
    }

    /// Returns whether the capture resolution has been explicitly defined.
    public func getIsRatioDefined() -> Bool {
        return isRatioDefined
    }
}

// MARK: - RTCPeerConnectionDelegate

extension ScreenShareWebRTCClient: RTCPeerConnectionDelegate {

    public func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCSignalingState) {
        logger.info("Signaling state changed: \(state.rawValue)")
        delegate?.webRTCClient(self, didChangeSignalingState: state)
    }

    public func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        logger.info("ICE connection state: \(newState.rawValue)")
        delegate?.webRTCClient(self, didChangeIceConnectionState: newState)
    }

    public func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        logger.info("ICE gathering state: \(newState.rawValue)")
        delegate?.webRTCClient(self, didChangeIceGatheringState: newState)
    }

    public func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        logger.info("Discovered new ICE candidate")
        delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }

    public func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.info("Added media stream: \(stream.streamId)")
    }

    public func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.info("Removed media stream: \(stream.streamId)")
    }

    public func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {
        logger.info("Negotiation needed")
    }

    public func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        logger.info("Removed ICE candidates")
    }

    public func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        logger.info("Opened data channel")
    }
}

// MARK: - Track Enable/Disable Utilities

extension ScreenShareWebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
        peerConnection.transceivers
            .compactMap { $0.sender.track as? T }
            .forEach { $0.isEnabled = isEnabled }
    }
}

// MARK: - Video Track Controls

extension ScreenShareWebRTCClient {
    func hideVideo() { setVideoEnabled(false) }
    func showVideo() { setVideoEnabled(true) }

    private func setVideoEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCVideoTrack.self, isEnabled: isEnabled)
    }
}

// MARK: - Audio Track Controls

extension ScreenShareWebRTCClient {
    func muteAudio() { setAudioEnabled(false) }
    func unmuteAudio() { setAudioEnabled(true) }

    private func setAudioEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
    }

    func speakerOff() {
        // Stub: implement audio routing override if needed
    }

    func speakerOn() {
        // Stub: implement audio routing override if needed
    }
}

// MARK: - RTCDataChannelDelegate

extension ScreenShareWebRTCClient: RTCDataChannelDelegate {
    public func dataChannelDidChangeState(_ channel: RTCDataChannel) {
        debugPrint("DataChannel state changed: \(channel.readyState)")
    }

    public func dataChannel(_ channel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        debugPrint("DataChannel received message: \(buffer)")
    }
}
