import Foundation
import AuroraCore

/// Wire protocol for Skydimo USB-serial LED controllers.
///
/// Reverse-engineered from the official app — full notes in
/// `docs/protocol/skydimo-serial-re.md`. Summary:
///   • 115200 baud, 8 data bits, no parity, 1 stop bit, over a CH340 USB bridge
///     that enumerates as `/dev/cu.*`.
///   • Handshake: host writes ASCII `"Moni-A"`; a genuine controller replies with
///     a model string whose uppercased form starts with `"SK"` (e.g. `"SK0124"`).
///   • Frame: 6-byte header `41 64 61 00 HH LL` ("Ada", pad, big-endian LED count)
///     followed by `count * 3` payload bytes. No checksum, no terminator.
///   • Per-LED order is R,G,B on the host side. WS2812-class strips may need GRB —
///     confirmed per controller during hardware bring-up (M2).
public enum SkydimoProtocol {
    public static let handshakeRequest = Data("Moni-A".utf8)
    public static let productReplyPrefix = "SK"
    public static let baudRate: Int32 = 115_200

    /// Per-LED byte order on the wire.
    public enum ChannelOrder: String, CaseIterable, Sendable {
        case rgb, grb, bgr
    }

    /// Whether the header count field encodes the LED count (Skydimo) or
    /// count-1 (classic Adalight). Skydimo uses the plain count.
    public enum CountEncoding: Sendable {
        case count
        case countMinusOne
    }

    /// Build a complete wire frame for the given pixels.
    public static func frame(
        _ pixels: [RGB],
        order: ChannelOrder = .rgb,
        countEncoding: CountEncoding = .count
    ) -> Data {
        let n = pixels.count
        let encoded = countEncoding == .count ? n : max(0, n - 1)

        var data = Data()
        data.reserveCapacity(6 + n * 3)
        data.append(contentsOf: [0x41, 0x64, 0x61, 0x00])   // "Ada" + pad byte
        data.append(UInt8((encoded >> 8) & 0xFF))           // count high byte
        data.append(UInt8(encoded & 0xFF))                  // count low byte

        for p in pixels {
            switch order {
            case .rgb: data.append(contentsOf: [p.r, p.g, p.b])
            case .grb: data.append(contentsOf: [p.g, p.r, p.b])
            case .bgr: data.append(contentsOf: [p.b, p.g, p.r])
            }
        }
        return data
    }

    /// True if a handshake reply identifies a genuine Skydimo controller.
    public static func isValidReply(_ reply: String) -> Bool {
        reply
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .hasPrefix(productReplyPrefix)
    }
}
