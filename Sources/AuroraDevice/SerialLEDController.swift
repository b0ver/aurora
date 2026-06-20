import Foundation
import AuroraCore
#if canImport(Darwin)
import Darwin
#endif

public enum DeviceError: Error, CustomStringConvertible {
    case openFailed(String)
    case configFailed(String)
    case notConnected
    case writeFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let s):   return "Failed to open serial port: \(s)"
        case .configFailed(let s): return "Failed to configure serial port: \(s)"
        case .notConnected:        return "Serial port is not connected"
        case .writeFailed(let s):  return "Serial write failed: \(s)"
        }
    }
}

/// Real hardware backend: opens a `/dev/cu.*` port, performs the Skydimo
/// handshake, and writes RGB frames per `SkydimoProtocol`.
///
/// The protocol is decoded (see docs/protocol/), but channel order (RGB vs GRB)
/// and the exact device must still be confirmed against physical hardware in M2.
public final class SerialLEDController: LEDController {
    public let layout: LEDLayout
    public let portPath: String
    public var channelOrder: SkydimoProtocol.ChannelOrder
    public private(set) var isConnected = false
    public private(set) var productID: String?

    private var fd: Int32 = -1

    public init(
        layout: LEDLayout,
        portPath: String,
        channelOrder: SkydimoProtocol.ChannelOrder = .rgb
    ) {
        self.layout = layout
        self.portPath = portPath
        self.channelOrder = channelOrder
    }

    /// Candidate serial devices (`/dev/cu.*`). The Skydimo bridge is a CH340; we
    /// confirm a specific port by handshake rather than by name.
    public static func availablePorts() -> [String] {
        let dev = "/dev"
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: dev)) ?? []
        return entries
            .filter { $0.hasPrefix("cu.") }
            .map { "\(dev)/\($0)" }
            .sorted()
    }

    public func connect() throws {
        let handle = portPath.withCString { open($0, O_RDWR | O_NOCTTY | O_NONBLOCK) }
        guard handle >= 0 else {
            throw DeviceError.openFailed("\(portPath): \(String(cString: strerror(errno)))")
        }
        fd = handle

        var tty = termios()
        guard tcgetattr(fd, &tty) == 0 else {
            disconnect()
            throw DeviceError.configFailed("tcgetattr: \(String(cString: strerror(errno)))")
        }

        cfmakeraw(&tty)
        cfsetispeed(&tty, speed_t(B115200))
        cfsetospeed(&tty, speed_t(B115200))
        tty.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tty.c_cflag &= ~tcflag_t(PARENB)            // no parity
        tty.c_cflag &= ~tcflag_t(CSTOPB)            // 1 stop bit
        tty.c_cflag &= ~tcflag_t(CSIZE)
        tty.c_cflag |= tcflag_t(CS8)                // 8 data bits

        guard tcsetattr(fd, TCSANOW, &tty) == 0 else {
            disconnect()
            throw DeviceError.configFailed("tcsetattr: \(String(cString: strerror(errno)))")
        }

        handshake()
        isConnected = true
    }

    /// Best-effort handshake: send "Moni-A", read the model reply if any. Some
    /// firmware may not reply; we record what we get and proceed.
    private func handshake() {
        _ = try? writeData(SkydimoProtocol.handshakeRequest)

        var collected = [UInt8]()
        var attempts = 0
        while attempts < 12 {
            var buf = [UInt8](repeating: 0, count: 64)
            let n = read(fd, &buf, buf.count)
            if n > 0 {
                collected.append(contentsOf: buf[0..<n])
                if collected.count >= 2 { break }
            }
            usleep(20_000)
            attempts += 1
        }

        if !collected.isEmpty {
            let reply = String(decoding: collected, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            productID = reply
        }
    }

    public func render(_ frame: [RGB]) {
        guard isConnected else { return }
        let data = SkydimoProtocol.frame(frame, order: channelOrder)
        _ = try? writeData(data)
    }

    @discardableResult
    private func writeData(_ data: Data) throws -> Int {
        guard fd >= 0 else { throw DeviceError.notConnected }
        var total = 0
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            while total < data.count {
                let w = write(fd, base + total, data.count - total)
                if w > 0 {
                    total += w
                } else if w < 0 {
                    if errno == EAGAIN || errno == EWOULDBLOCK {
                        usleep(500)
                        continue
                    }
                    throw DeviceError.writeFailed(String(cString: strerror(errno)))
                } else {
                    break
                }
            }
        }
        return total
    }

    public func disconnect() {
        if fd >= 0 { close(fd) }
        fd = -1
        isConnected = false
    }

    deinit { disconnect() }
}
