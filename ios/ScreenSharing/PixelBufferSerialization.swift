//
//  PixelBufferSerialization.swift
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs on 06/07/25.
//  Last full rewrite: 06/07/25 — added dataSize to header for safer decoding.
//

import Foundation
import CoreVideo
import CoreMedia
import ImageIO   // for CGImagePropertyOrientation

// MARK: – Constants

/// ASCII prefix used for a quick sanity‑check.
private let kPrefix = Data("BBB".utf8)          // 3 bytes

// MARK: – Header layout
//
// UInt32 width
// UInt32 height
// UInt32 pixelFormat (FourCC)
// UInt32 bytesPerRow
// UInt32 dataSize (pixel payload length in bytes)
// UInt32 orientation (CGImagePropertyOrientation.rawValue)
// UInt32 cookie (random; repeated at tail)
//
// Packet = "BBB"  + header (28 bytes) + pixel bytes + cookie trailer (4 bytes)

private struct PixelHeader {
    static let size = 7 * MemoryLayout<UInt32>.size   // 28 bytes

    var width:       UInt32
    var height:      UInt32
    var pixelFormat: UInt32
    var bytesPerRow: UInt32
    var dataSize:    UInt32
    var orientation: UInt32
    var cookie:      UInt32

    /// Full memberwise initialiser (needed because we define another init below).
    init(width: UInt32, height: UInt32, pixelFormat: UInt32,
         bytesPerRow: UInt32, dataSize: UInt32, orientation: UInt32, cookie: UInt32) {
        self.width       = width
        self.height      = height
        self.pixelFormat = pixelFormat
        self.bytesPerRow = bytesPerRow
        self.dataSize    = dataSize
        self.orientation = orientation
        self.cookie      = cookie
    }

    /// Build header from a live pixel‑buffer (single‑plane formats only).
    init(buffer: CVPixelBuffer,
         orientation: CGImagePropertyOrientation,
         cookie: UInt32 = .random(in: 1 ... 9000)) {
        let pixelBytes = UInt32(CVPixelBufferGetDataSize(buffer))
        self.init(width:       UInt32(CVPixelBufferGetWidth(buffer)),
                  height:      UInt32(CVPixelBufferGetHeight(buffer)),
                  pixelFormat: CVPixelBufferGetPixelFormatType(buffer),
                  bytesPerRow: UInt32(CVPixelBufferGetBytesPerRow(buffer)),
                  dataSize:    pixelBytes,
                  orientation: UInt32(orientation.rawValue),
                  cookie:      cookie)
    }

    /// Native‑endian encode (all current Apple silicon & Intel are little‑endian).
    func encode() -> Data {
        var tmp = self
        return Data(bytes: &tmp, count: PixelHeader.size)
    }

    /// Alignment‑safe decode.
    static func decode(from data: Data) -> PixelHeader? {
        guard data.count >= PixelHeader.size else { return nil }
        return data.withUnsafeBytes { rawPtr -> PixelHeader in
            var hdr = PixelHeader(width: 0, height: 0, pixelFormat: 0,
                                   bytesPerRow: 0, dataSize: 0, orientation: 0, cookie: 0)
            memcpy(&hdr, rawPtr.baseAddress!, PixelHeader.size)
            return hdr
        }
    }
}

// MARK: – Errors

enum PBDeserializationError: Error {
    case prefixMissing
    case headerTooShort
    case invalidHeader
    case inconsistentStride
    case sizeMismatch(expected: Int, got: Int)
    case cookieMismatch(expected: UInt32, got: UInt32)
    case pixelBufferCreateFailed
    case baseAddressUnavailable
}

// MARK: – Serialization

/// Serialises a **single‑plane** pixel‑buffer into Data.
/// Layout: "BBB" prefix → 28‑byte header → pixel bytes → 4‑byte cookie trailer.
func serializePixelBufferFull(_ pixelBuffer: CVPixelBuffer,
                              orientation: CGImagePropertyOrientation = .up) -> Data? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let basePtr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

    let pixelBytes = CVPixelBufferGetDataSize(pixelBuffer)
    let header      = PixelHeader(buffer: pixelBuffer, orientation: orientation)
    let headerData  = header.encode()

    var out = Data(capacity: kPrefix.count + headerData.count + pixelBytes + 4)
    out.append(kPrefix)                                               // 1) prefix
    out.append(headerData)                                            // 2) header
    out.append(basePtr.assumingMemoryBound(to: UInt8.self),           // 3) pixels
               count: pixelBytes)

    var trailerLE = header.cookie.littleEndian
    out.append(Data(bytes: &trailerLE, count: 4))                     // 4) trailer
    
    return out
}

// MARK: – Deserialization

/// Reverses serializePixelBufferFull. Throws if malformed or corrupted.
func deserializePixelBufferFull(_ data: Data) throws -> (buffer: CVPixelBuffer,
                                                       orientation: CGImagePropertyOrientation) {
    // 0. Prefix
    guard data.starts(with: kPrefix) else { throw PBDeserializationError.prefixMissing }

    let headerStart = kPrefix.count
    let headerEnd   = headerStart + PixelHeader.size
    guard data.count >= headerEnd else { throw PBDeserializationError.headerTooShort }

    // 1. Header
    let headerData = data.subdata(in: headerStart..<headerEnd)
    guard let header = PixelHeader.decode(from: headerData) else {
        throw PBDeserializationError.invalidHeader
    }

    // 2. Trailer (cookie)
    let trailerOffset = headerEnd + Int(header.dataSize)
    guard trailerOffset >= headerEnd else {
        throw PBDeserializationError.sizeMismatch(expected: headerEnd + 4, got: data.count)
    }

    var trailerCookie: UInt32 = 0
    _ = withUnsafeMutableBytes(of: &trailerCookie) { dst -> Int in
        data.copyBytes(to: dst, from: trailerOffset..<(trailerOffset + 4))
    }
    trailerCookie = UInt32(littleEndian: trailerCookie)
    guard trailerCookie == header.cookie else {
        throw PBDeserializationError.cookieMismatch(expected: header.cookie, got: trailerCookie)
    }

    // 4. Create pixel‑buffer
    var pbOpt: CVPixelBuffer?
    let attrs: CFDictionary = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ] as CFDictionary

    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(header.width),
                                     Int(header.height),
                                     header.pixelFormat,
                                     attrs,
                                     &pbOpt)
    guard status == kCVReturnSuccess, let pixelBuffer = pbOpt else {
        throw PBDeserializationError.pixelBufferCreateFailed
    }

    // 5. Copy pixels
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let destPtr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        throw PBDeserializationError.baseAddressUnavailable
    }

    let pixelRange = headerEnd..<trailerOffset
    data.copyBytes(to: destPtr.assumingMemoryBound(to: UInt8.self), from: pixelRange)

    let orientation = CGImagePropertyOrientation(rawValue: header.orientation) ?? .up
    return (pixelBuffer, orientation)
}
