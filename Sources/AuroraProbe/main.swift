import Foundation
import Darwin
import AuroraCore
import AuroraDevice
import AuroraCircadian

// AuroraProbe — M2 hardware bring-up CLI.
//
//   swift run AuroraProbe                                   list serial ports
//   swift run AuroraProbe handshake [port]                  identify the controller
//   swift run AuroraProbe test [port] [count] [rgb|grb]     color / channel-order test
//   swift run AuroraProbe circadian [port] [count] [rgb|grb] live circadian for 30s
//
// IMPORTANT: quit the native Skydimo app first — the serial port is exclusive.

func availablePorts() -> [String] { SerialLEDController.availablePorts() }

/// USB serial candidates worth probing (skip Bluetooth / debug-console).
func candidatePorts() -> [String] {
    availablePorts().filter {
        let l = $0.lowercased()
        return l.contains("usbserial") || l.contains("wch") || l.contains("usbmodem")
    }
}

/// Rank CH340-style names first (Skydimo uses a CH340 bridge → usbserial/wch).
func portRank(_ path: String) -> Int {
    let l = path.lowercased()
    if l.contains("wch") { return 0 }
    if l.contains("usbserial") { return 1 }
    if l.contains("usbmodem") { return 2 }
    return 3
}

func autoPort() -> String? {
    candidatePorts().min(by: { portRank($0) < portRank($1) }) ?? availablePorts().first
}

/// Open a port, handshake, return the (port, reply) if it answered at all.
func probeHandshake(_ port: String) -> String? {
    let controller = SerialLEDController(layout: .strip(count: 1), portPath: port)
    guard (try? controller.connect()) != nil else { return nil }
    let reply = controller.productID ?? ""
    controller.disconnect()
    return reply
}

func parseOrder(_ s: String?) -> SkydimoProtocol.ChannelOrder {
    switch (s ?? "rgb").lowercased() {
    case "grb": return .grb
    case "bgr": return .bgr
    default: return .rgb
    }
}

/// model id → LED count, from the vendor SKController.json catalog.
func ledCount(forModel model: String) -> Int? {
    let path = "docs/reference/controller-configs/SKController.json"
    guard let data = FileManager.default.contents(atPath: path),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    let key = String(model.uppercased().prefix(6))
    guard let entry = obj[key] as? [String: Any], let n = entry["nbLeds"] as? Int else { return nil }
    return n
}

func connect(port: String, count: Int, order: SkydimoProtocol.ChannelOrder) -> SerialLEDController? {
    let controller = SerialLEDController(layout: .strip(count: count), portPath: port, channelOrder: order)
    do {
        try controller.connect()
    } catch {
        print("✗ connect failed: \(error)")
        return nil
    }
    print("✓ opened \(port)")
    let reply = controller.productID ?? ""
    print(reply.isEmpty ? "  (no handshake reply)" : "  handshake reply: \"\(reply)\"")
    return controller
}

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "list"
let rest = Array(args.dropFirst())

switch command {
case "list":
    let ports = availablePorts()
    print("Serial ports (/dev/cu.*):")
    ports.isEmpty ? print("  (none found — is the controller plugged in?)") : ports.forEach { print("  \($0)") }
    if let best = autoPort() { print("\nBest guess: \(best)") }
    print("Next: quit the native Skydimo app, then `swift run AuroraProbe handshake`")

case "handshake":
    func report(_ port: String, _ reply: String) {
        if SkydimoProtocol.isValidReply(reply) {
            let model = String(reply.uppercased().prefix(6))
            let count = ledCount(forModel: model)
            print("✓ \(port) → Skydimo controller, model \(model)" + (count.map { ", \($0) LEDs" } ?? " (LED count unknown)"))
        } else {
            print("  \(port) → \(reply.isEmpty ? "(no reply)" : "\"\(reply)\"") — not a Skydimo handshake")
        }
    }
    if let port = rest.first {
        guard let reply = probeHandshake(port) else { print("✗ could not open \(port)"); exit(1) }
        report(port, reply)
    } else {
        let ports = candidatePorts()
        print("Scanning \(ports.count) USB port(s)…  (quit the native Skydimo app first!)")
        var found: String?
        for port in ports.sorted(by: { portRank($0) < portRank($1) }) {
            guard let reply = probeHandshake(port) else { print("  \(port) → busy/unopenable (native app still holding it?)"); continue }
            report(port, reply)
            if found == nil, SkydimoProtocol.isValidReply(reply) { found = port }
        }
        if let f = found {
            print("\n✅ Controller is on \(f). Next: `swift run AuroraProbe test \(f)`")
        } else {
            print("\n⚠︎ No Skydimo controller answered. Quit the native Skydimo app fully and retry.")
        }
    }

case "test":
    guard let port = rest.first ?? autoPort() else { print("no port found"); exit(1) }
    let count = Int(rest.dropFirst().first ?? "") ?? 54
    let order = parseOrder(rest.dropFirst(2).first)
    guard let controller = connect(port: port, count: count, order: order) else { exit(1) }

    func hold(_ name: String, _ color: RGB, seconds: Double) {
        print("→ \(name): emitting \(color) in \(order.rawValue.uppercased()) order — WATCH THE STRIP")
        let frames = Int(seconds * 20)
        for _ in 0..<frames {
            controller.render(Array(repeating: color, count: count))
            usleep(50_000)
        }
    }

    hold("RED",   RGB(r: 255, g: 0, b: 0), seconds: 3)
    hold("GREEN", RGB(r: 0, g: 255, b: 0), seconds: 3)
    hold("BLUE",  RGB(r: 0, g: 0, b: 255), seconds: 3)
    hold("WHITE", RGB(r: 255, g: 255, b: 255), seconds: 2)

    print("→ CHASE: one white dot should travel end-to-end (checks order + direction)")
    for i in 0..<count {
        var frame = Array(repeating: RGB.black, count: count)
        frame[i] = .white
        controller.render(frame)
        usleep(60_000)
    }
    controller.render(Array(repeating: RGB.black, count: count))
    controller.disconnect()

    print("""

    Report what you actually saw:
      • RED→red, GREEN→green, BLUE→blue   ⇒ channel order is RGB ✅
      • RED→green, GREEN→red, BLUE→blue   ⇒ order is GRB → re-run: AuroraProbe test \(port) \(count) grb
      • anything else                     ⇒ tell me the colors and I'll work out the order
      • dot travelled right-to-left / wrong start ⇒ note it, that's the layout direction (setup screen)
    """)

case "circadian":
    guard let port = rest.first ?? autoPort() else { print("no port found"); exit(1) }
    let count = Int(rest.dropFirst().first ?? "") ?? 54
    let order = parseOrder(rest.dropFirst(2).first)
    guard let controller = connect(port: port, count: count, order: order) else { exit(1) }
    let mode = CircadianMode(settings: CircadianSettings(latitude: 55.75, longitude: 37.62))
    print("Running circadian on the real strip for 30s (Ctrl-C to stop early)…")
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
        controller.render(mode.frame(at: Date(), layout: controller.layout))
        usleep(200_000)
    }
    controller.render(Array(repeating: RGB.black, count: count))
    controller.disconnect()
    print("✓ done")

default:
    print("unknown command: \(command)")
    print("usage: list | handshake [port] | test [port] [count] [rgb|grb] | circadian [port] [count] [rgb|grb]")
}
