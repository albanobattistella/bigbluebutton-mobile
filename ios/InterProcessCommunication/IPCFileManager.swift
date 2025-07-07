//
//  IPCFileManager.swift
//  bigbluebuttontablet
//
//  Provides shared memory-mapped file access for communication between the
//  Broadcast extension and the main application.
//

import Foundation

// MARK: - Low-level helper ----------------------------------------------------

/// Manages memory-mapped I/O operations on arbitrary files (via path and size).
/// Each operation maps the file, executes the operation, then unmaps and closes it.
public final class IPCFileManager {

    public static let shared = IPCFileManager()
    private init() {}

    // MARK: Public read / write API

    /// Writes `data` to the specified `offset` in a memory-mapped file.
    /// Automatically creates the file if it doesn't exist.
    /// Returns `false` on invalid parameters or POSIX errors.
    @discardableResult
    public func write(_ data: Data,
                      to path: String,
                      size: Int,
                      at offset: Int = 0) -> Bool {

        guard offset >= 0, offset + data.count <= size else { return false }

        guard let (fd, _, mem) = mapFile(path: path, size: size),
              let mem = mem else { return false }

        data.withUnsafeBytes { src in
            memcpy(mem.advanced(by: offset), src.baseAddress!, data.count)
        }

        msync(mem, size, MS_SYNC) // Ensure changes are flushed to disk
        unmapFile(fd: fd, mem: mem, size: size)
        return true
    }

    /// Reads `count` bytes from the file at the specified `offset`.
    /// Returns the result as `Data`, or `nil` on failure.
    public func read(from path: String,
                     size: Int,
                     count: Int,
                     offset: Int = 0) -> Data? {

        guard offset >= 0, offset + count <= size else { return nil }

        guard let (fd, _, mem) = mapFile(path: path, size: size),
              let mem = mem else { return nil }

        let bytes = UnsafeRawPointer(mem.advanced(by: offset))
        let data  = Data(bytes: bytes, count: count)

        unmapFile(fd: fd, mem: mem, size: size)
        return data
    }

    // MARK: POSIX mapping helpers

    /// Maps a file into memory with read/write access. Returns file descriptor, size, and pointer.
    private func mapFile(path: String,
                         size: Int,
                         options: Int32 = O_RDWR | O_CREAT)
        -> (fd: Int32, sz: Int, mem: UnsafeMutableRawPointer?)? {

        let fd = open(path, options, 0o666) // rw-rw-rw-
        guard fd >= 0 else { return nil }

        if ftruncate(fd, off_t(size)) != 0 { // Resize file if needed
            close(fd); return nil
        }

        let mem = mmap(nil, size,
                       PROT_READ | PROT_WRITE,
                       MAP_SHARED, fd, 0)
        guard mem != MAP_FAILED else {
            close(fd); return nil
        }
        return (fd, size, mem)
    }

    /// Unmaps and closes the given memory-mapped file.
    private func unmapFile(fd: Int32,
                           mem: UnsafeMutableRawPointer,
                           size: Int) {
        munmap(mem, size)
        close(fd)
    }
  
    /// Clears the entire file by filling it with zeroes.
    /// - Parameters:
    ///   - path: Absolute path of the file to clear.
    ///   - size: Expected size of the file (bytes).
    /// - Returns: `false` on parameter or POSIX failure; `true` on success.
    @discardableResult
    public func clear(path: String, size: Int) -> Bool {
        guard let (fd, _, mem) = mapFile(path: path, size: size),
              let mem = mem else { return false }

        memset(mem, 0, size)               // Fast zero-fill
        msync(mem, size, MS_SYNC)          // Flush to disk
        unmapFile(fd: fd, mem: mem, size: size)
        return true
    }

}

// MARK: - High-level, user-facing wrapper ------------------------------------

/// High-level wrapper for managing the shared memory file used to store the current video frame.
public final class IPCCurrentVideoFrame {

    public static let shared = IPCCurrentVideoFrame()
    private init() {}

    // Configuration for the shared memory file
    private static let appGroupID  = "group.org.bigbluebutton.tablet"
    private static let fileSize    = 20 * 1024 * 1024 // 20 MB

    /// Path to the shared memory file within the app group container
    private static var filePath: String = {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                fatalError("App Group container not found")
        }
        return url.appendingPathComponent("currentFrame.mmap").path
    }()

    // MARK: Public API

    /// Writes a full video frame (or a segment) to the shared file at the specified `offset`.
    @discardableResult
    public func set(_ data: Data, at offset: Int = 0) -> Bool {
        return IPCFileManager.shared.write(data,
                                    to: Self.filePath,
                                    size: Self.fileSize,
                                    at: offset)
    }

    /// Reads a specified number of bytes starting from the given `offset`.
    public func get(count: Int = 0, from offset: Int = 0) -> Data? {
        return IPCFileManager.shared.read(from: Self.filePath,
                                   size: Self.fileSize,
                                   count: count == 0 ? Self.fileSize : count,
                                   offset: offset)
    }
  
    /// Zeroes-out the shared memory file so readers see an “empty” frame.
    @discardableResult
    public func clear() -> Bool {
        return IPCFileManager.shared.clear(
            path: Self.filePath,
            size: Self.fileSize
        )
    }

}
