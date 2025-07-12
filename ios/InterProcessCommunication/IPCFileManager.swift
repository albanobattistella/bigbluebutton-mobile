//
//  IPCFileManager.swift
//  bigbluebuttontablet
//
//  Provides shared memory-mapped file access for communication between the
//  Broadcast extension and the main application.
// 
//  Created by Tiago Daniel Jacobs, 2025

import Foundation

// MARK: - Low-level POSIX Memory-Mapping Manager

/// Handles memory-mapped file I/O using POSIX system calls.
/// Each operation maps the file into memory, performs the read/write,
/// and then safely unmaps and closes the file.
public final class IPCFileManager {

    public static let shared = IPCFileManager()
    private init() {}

    // MARK: - Public API

    /// Writes the given `data` to the specified `offset` in a memory-mapped file.
    /// If the file does not exist, it is created and sized appropriately.
    ///
    /// - Returns: `false` if the input is invalid or any file I/O error occurs.
    @discardableResult
    public func write(_ data: Data,
                      to path: String,
                      size: Int,
                      at offset: Int = 0) -> Bool {
        guard offset >= 0, offset + data.count <= size else { return false }

        guard let (fd, _, mem) = mapFile(path: path, size: size), let mem = mem else {
            return false
        }

        data.withUnsafeBytes { src in
            memcpy(mem.advanced(by: offset), src.baseAddress!, data.count)
        }

        msync(mem, size, MS_SYNC) // Flush changes to disk
        unmapFile(fd: fd, mem: mem, size: size)
        return true
    }

    /// Reads `count` bytes from the file starting at `offset`.
    ///
    /// - Returns: `Data` if successful, or `nil` on failure.
    public func read(from path: String,
                     size: Int,
                     count: Int,
                     offset: Int = 0) -> Data? {
        guard offset >= 0, offset + count <= size else { return nil }

        guard let (fd, _, mem) = mapFile(path: path, size: size), let mem = mem else {
            return nil
        }

        let bytes = UnsafeRawPointer(mem.advanced(by: offset))
        let data = Data(bytes: bytes, count: count)

        unmapFile(fd: fd, mem: mem, size: size)
        return data
    }

    /// Clears the entire file by zero-filling it.
    @discardableResult
    public func clear(path: String, size: Int) -> Bool {
        guard let (fd, _, mem) = mapFile(path: path, size: size), let mem = mem else {
            return false
        }

        memset(mem, 0, size)
        msync(mem, size, MS_SYNC)
        unmapFile(fd: fd, mem: mem, size: size)
        return true
    }

    /// Checks whether the first 3 bytes of the mapped file are zero.
    /// Used to determine whether the file represents a “clean” frame.
    public func isClean(path: String, size: Int) -> Bool {
        guard let (fd, _, mem) = mapFile(path: path, size: size), let mem = mem else {
            return false
        }

        let b0 = mem.load(fromByteOffset: 0, as: UInt8.self)
        let b1 = mem.load(fromByteOffset: 1, as: UInt8.self)
        let b2 = mem.load(fromByteOffset: 2, as: UInt8.self)

        unmapFile(fd: fd, mem: mem, size: size)
        return b0 == 0 && b1 == 0 && b2 == 0
    }

    // MARK: - Internal Mapping Utilities

    /// Maps a file into memory using mmap().
    /// - Returns: file descriptor, size, and mapped memory pointer.
    private func mapFile(path: String,
                         size: Int,
                         options: Int32 = O_RDWR | O_CREAT)
        -> (fd: Int32, sz: Int, mem: UnsafeMutableRawPointer?)? {

        let fd = open(path, options, 0o666) // rw-rw-rw-
        guard fd >= 0 else { return nil }

        if ftruncate(fd, off_t(size)) != 0 {
            close(fd)
            return nil
        }

        let mem = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        guard mem != MAP_FAILED else {
            close(fd)
            return nil
        }

        return (fd, size, mem)
    }

    /// Unmaps and closes a memory-mapped file safely.
    private func unmapFile(fd: Int32,
                           mem: UnsafeMutableRawPointer,
                           size: Int) {
        munmap(mem, size)
        close(fd)
    }
}

// MARK: - High-Level Shared Memory Manager

/// Provides safe, high-level access to a memory-mapped file representing
/// the current screen-share frame. Wraps IPCFileManager internally.
public final class IPCCurrentVideoFrame {

    public static let shared = IPCCurrentVideoFrame()
    private init() {}

    // MARK: - Shared File Configuration

    private static let appGroupID = "group.org.bigbluebutton.tablet"
    private static let fileSize = 20 * 1024 * 1024 // 20 MB max buffer

    /// Absolute file path for the memory-mapped frame file.
    private static var filePath: String = {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("App Group container not found")
        }
        return url.appendingPathComponent("currentFrame.mmap").path
    }()

    // MARK: - Public Frame API

    /// Writes data to shared memory at a given offset.
    @discardableResult
    public func set(_ data: Data, at offset: Int = 0) -> Bool {
        return IPCFileManager.shared.write(
            data,
            to: Self.filePath,
            size: Self.fileSize,
            at: offset
        )
    }

    /// Reads a specified number of bytes from shared memory.
    /// Defaults to full file size if count == 0.
    public func get(count: Int = 0, from offset: Int = 0) -> Data? {
        return IPCFileManager.shared.read(
            from: Self.filePath,
            size: Self.fileSize,
            count: count == 0 ? Self.fileSize : count,
            offset: offset
        )
    }

    /// Zeroes out the shared memory, marking it as clean/unused.
    @discardableResult
    public func clear() -> Bool {
        return IPCFileManager.shared.clear(
            path: Self.filePath,
            size: Self.fileSize
        )
    }

    /// Returns true if the shared memory contains no pixel data.
    public func isClean() -> Bool {
        return IPCFileManager.shared.isClean(
            path: Self.filePath,
            size: Self.fileSize
        )
    }
}
