//
//  PixelBufferSerialization.swift
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs, 2025
//

import Foundation
import CoreVideo
import CoreMedia
import ImageIO // for CGImagePropertyOrientation

// MARK: - Constants

/// ASCII prefix used as a sanity check before decoding pixel buffer payloads.
private let kPrefix = Data("BBB".utf8) // 3 bytes

// MARK: - Header Definition

/// Describes the binary layout of the serialized pixel buffer header.
/// Total header size: 28 bytes + 8 (timestamp) = 36 bytes.
public struct PixelHeader {
    static let size = 7 * MemoryLayout<UInt32>.size + MemoryLayout<Int64>.size

    var timestampNs: Int64
    var width:       UInt32
    var height:      UInt32
    var pixelFormat: UInt32
    var bytesPerRow: UInt32
    var dataSize:    UInt32
    var orientation: UInt32
    var cookie:      UInt32

    /// Full initializer for manual construction.
    init(
        timestampNs: Int64,
        width: UInt32,
        height: UInt32,
        pixelFormat: UInt32,
        bytesPerRow: UInt32,
        dataSize: UInt32,
        orientation: UInt32,
        cookie: UInt32
    ) {
        self.timestampNs = timestampNs
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.bytesPerRow = bytesPerRow
        self.dataSize = dataSize
        self.orientation = orientation
        self.cookie = cookie
    }

    /// Initializes header from a live pixel buffer (only supports single-plane).
    init(
        timestampNs: Int64,
        buffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        cookie: UInt32 = .random(in: 1...9000)
    ) {
        let pixelBytes = UInt32(CVPixelBufferGetDataSize(buffer))
        self.init(
            timestampNs: timestampNs,
            width: UInt32(CVPixelBufferGetWidth(buffer)),
            height: UInt32(CVPixelBufferGetHeight(buffer)),
            pixelFormat: CVPixelBufferGetPixelFormatType(buffer),
            bytesPerRow: UInt32(CVPixelBufferGetBytesPerRow(buffer)),
            dataSize: pixelBytes,
            orientation: UInt32(orientation.rawValue),
            cookie: cookie
        )
    }

    /// Encodes the struct into raw Data using native-endian layout.
    func encode() -> Data {
        var tmp = self
        return Data(bytes: &tmp, count: PixelHeader.size)
    }

    /// Decodes a header from Data. Returns nil if data is insufficient.
    static func decode(from data: Data) -> PixelHeader? {
        guard data.count >= PixelHeader.size else { return nil }
        return data.withUnsafeBytes { rawPtr -> PixelHeader in
            var hdr = PixelHeader(
                timestampNs: 0,
                width: 0,
                height: 0,
                pixelFormat: 0,
                bytesPerRow: 0,
                dataSize: 0,
                orientation: 0,
                cookie: 0
            )
            memcpy(&hdr, rawPtr.baseAddress!, PixelHeader.size)
            return hdr
        }
    }
}

// MARK: - Deserialization Errors

/// Errors thrown when decoding a pixel buffer fails due to malformed layout or mismatch.
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

// MARK: - Serialization

/// Serializes a pixel buffer (single-plane only) to binary format.
/// Layout:
/// - 1) 3-byte prefix `"BBB"`
/// - 2) 36-byte header (PixelHeader)
/// - 3) Raw pixel bytes
/// - 4) 4-byte trailer with repeated cookie
func serializePixelBufferFull(
    pixelBuffer: CVPixelBuffer,
    orientation: CGImagePropertyOrientation = .up,
    timestampNs: Int64
) -> Data? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let basePtr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

    let pixelBytes = CVPixelBufferGetDataSize(pixelBuffer)
    let header = PixelHeader(
        timestampNs: timestampNs,
        buffer: pixelBuffer,
        orientation: orientation
    )
    let headerData = header.encode()

    var out = Data(capacity: kPrefix.count + headerData.count + pixelBytes + 4)
    out.append(kPrefix) // Step 1: Prefix
    out.append(headerData) // Step 2: Header
    out.append(basePtr.assumingMemoryBound(to: UInt8.self), count: pixelBytes) // Step 3: Pixel bytes

    var trailerLE = header.cookie.littleEndian
    out.append(Data(bytes: &trailerLE, count: 4)) // Step 4: Trailer

    return out
}

// MARK: - Deserialization

/// Reverses `serializePixelBufferFull`, reconstructing the pixel buffer from data.
/// Ensures integrity using prefix, data length, and cookie checks.
func deserializePixelBufferFull(
    _ data: Data
) throws -> (
    buffer: CVPixelBuffer,
    orientation: CGImagePropertyOrientation,
    header: PixelHeader
) {
    // 0. Verify prefix
    guard data.starts(with: kPrefix) else {
        throw PBDeserializationError.prefixMissing
    }

    let headerStart = kPrefix.count
    let headerEnd = headerStart + PixelHeader.size
    guard data.count >= headerEnd else {
        throw PBDeserializationError.headerTooShort
    }

    // 1. Decode header
    let headerData = data.subdata(in: headerStart..<headerEnd)
    guard let header = PixelHeader.decode(from: headerData) else {
        throw PBDeserializationError.invalidHeader
    }

    // 2. Verify trailer (cookie match)
    let trailerOffset = headerEnd + Int(header.dataSize)
    guard trailerOffset + 4 <= data.count else {
        throw PBDeserializationError.sizeMismatch(
            expected: headerEnd + Int(header.dataSize) + 4,
            got: data.count
        )
    }

    var trailerCookie: UInt32 = 0
    _ = withUnsafeMutableBytes(of: &trailerCookie) { dst -> Int in
        data.copyBytes(to: dst, from: trailerOffset..<(trailerOffset + 4))
    }
    trailerCookie = UInt32(littleEndian: trailerCookie)
    guard trailerCookie == header.cookie else {
        throw PBDeserializationError.cookieMismatch(expected: header.cookie, got: trailerCookie)
    }

    // 3. Create pixel buffer
    var pbOpt: CVPixelBuffer?
    let attrs: CFDictionary = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ] as CFDictionary

    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(header.width),
        Int(header.height),
        header.pixelFormat,
        attrs,
        &pbOpt
    )
    guard status == kCVReturnSuccess, let pixelBuffer = pbOpt else {
        throw PBDeserializationError.pixelBufferCreateFailed
    }

    // 4. Copy pixel bytes
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let destPtr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        throw PBDeserializationError.baseAddressUnavailable
    }

    let pixelRange = headerEnd..<trailerOffset
    data.copyBytes(to: destPtr.assumingMemoryBound(to: UInt8.self), from: pixelRange)

    let orientation = CGImagePropertyOrientation(rawValue: header.orientation) ?? .up
    return (pixelBuffer, orientation, header)
}
