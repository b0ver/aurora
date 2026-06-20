import Foundation
import ScreenCaptureKit
import CoreMedia
import AVFoundation

/// Captures **system audio** (loopback) via ScreenCaptureKit and delivers mono
/// Float samples. Uses the same Screen Recording permission as screen capture.
final class AudioCapturer: NSObject, SCStreamOutput {
    var onSamples: (([Float]) -> Void)?
    private(set) var sampleRate: Double = 48_000

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.evgenypopov.aurora.audio", qos: .userInitiated)

    func start() async throws {
        guard stream == nil else { return }
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else { throw AudioCaptureError.noDisplay }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true
        // Keep the (unused) video path tiny — we only consume audio.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        sampleRate = 48_000

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == SCStreamError.errorDomain && (ns.code == -3801 || ns.code == -3802)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let samples = Self.extractMono(sampleBuffer) else { return }
        onSamples?(samples)
    }

    private static func extractMono(_ sb: CMSampleBuffer) -> [Float]? {
        var ablSize = 0
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sb, bufferListSizeNeededOut: &ablSize, bufferListOut: nil,
            bufferListSize: 0, blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: nil) == noErr, ablSize > 0
        else { return nil }

        let ablRaw = UnsafeMutableRawPointer.allocate(byteCount: ablSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { ablRaw.deallocate() }
        let ablPtr = ablRaw.assumingMemoryBound(to: AudioBufferList.self)
        var block: CMBlockBuffer?
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sb, bufferListSizeNeededOut: nil, bufferListOut: ablPtr,
            bufferListSize: ablSize, blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &block) == noErr
        else { return nil }

        let buffers = UnsafeMutableAudioBufferListPointer(ablPtr)
        guard let first = buffers.first, let data = first.mData else { return nil }
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size
        guard frames > 0 else { return nil }
        let fp = data.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: fp, count: frames))
    }
}

enum AudioCaptureError: Error { case noDisplay }
