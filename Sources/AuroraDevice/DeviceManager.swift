import Foundation
import AuroraCore

/// A Skydimo controller discovered on a serial port.
public struct DetectedController: Sendable {
    public let info: ControllerInfo
    public let portPath: String
}

/// Discovers Skydimo controllers on USB-serial ports via the handshake, and
/// builds a ready-to-use `SerialLEDController`. Shared by the app and AuroraProbe.
public enum DeviceManager {
    /// USB serial candidates worth probing (skip Bluetooth / debug-console).
    public static func candidatePorts() -> [String] {
        SerialLEDController.availablePorts().filter {
            let l = $0.lowercased()
            return l.contains("usbserial") || l.contains("wch") || l.contains("usbmodem")
        }
        .sorted(by: { rank($0) < rank($1) })
    }

    /// Scan ports, handshake each, and return the first genuine Skydimo controller
    /// (identity + port). Does not keep the port open.
    public static func detect() -> DetectedController? {
        for port in candidatePorts() {
            let probe = SerialLEDController(layout: .strip(count: 1), portPath: port)
            guard (try? probe.connect()) != nil else { continue }
            let reply = probe.productID ?? ""
            probe.disconnect()
            if let info = ControllerCatalog.info(forReply: reply) {
                return DetectedController(info: info, portPath: port)
            }
        }
        return nil
    }

    /// Build an (unconnected) controller for a detected device. The caller (engine)
    /// opens it via `connect()`.
    public static func makeController(
        for detected: DetectedController,
        channelOrder: SkydimoProtocol.ChannelOrder = .rgb
    ) -> SerialLEDController {
        SerialLEDController(
            layout: .strip(count: detected.info.ledCount),
            portPath: detected.portPath,
            channelOrder: channelOrder
        )
    }

    private static func rank(_ path: String) -> Int {
        let l = path.lowercased()
        if l.contains("wch") { return 0 }
        if l.contains("usbserial") { return 1 }
        if l.contains("usbmodem") { return 2 }
        return 3
    }
}
