import Foundation
import AuroraCore
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import CoreGraphics

/// Captures the main display via ScreenCaptureKit, downscaled to a small grid for
/// cheap edge sampling. Delivers `PixelGrid`s on a background queue.
final class ScreenCapturer: NSObject, SCStreamOutput {
    var onGrid: ((PixelGrid) -> Void)?

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "com.evgenypopov.aurora.capture", qos: .userInitiated)
    private let targetWidth = 96

    func start() async throws {
        guard stream == nil else { return }
        // Explicit Screen Recording gate: if not already granted, fire the system
        // prompt (takes effect after the next launch) and surface needsPermission.
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else { throw CaptureError.permissionDenied }

        let height = max(1, Int((Double(targetWidth) * Double(display.height) / Double(display.width)).rounded()))

        let config = SCStreamConfiguration()
        config.width = targetWidth
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 3
        config.showsCursor = false

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let grid = Self.makeGrid(pixelBuffer) else { return }
        onGrid?(grid)
    }

    /// True if the error is a Screen Recording permission denial.
    static func isPermissionError(_ error: Error) -> Bool {
        if case CaptureError.permissionDenied = error { return true }
        let ns = error as NSError
        // SCStreamErrorDomain userDeclined == -3801; -3802 also permission-related.
        return ns.domain == SCStreamError.errorDomain && (ns.code == -3801 || ns.code == -3802)
    }

    private static func makeGrid(_ pb: CVPixelBuffer) -> PixelGrid? {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        guard w > 0, h > 0, let base = CVPixelBufferGetBaseAddress(pb) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        var pixels = [RGB]()
        pixels.reserveCapacity(w * h)
        for y in 0..<h {
            let row = ptr + y * bytesPerRow
            for x in 0..<w {
                let o = x * 4                     // BGRA
                pixels.append(RGB(r: row[o + 2], g: row[o + 1], b: row[o]))
            }
        }
        return PixelGrid(width: w, height: h, pixels: pixels)
    }
}

enum CaptureError: Error { case noDisplay, permissionDenied }
