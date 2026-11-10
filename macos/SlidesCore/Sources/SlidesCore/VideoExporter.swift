@preconcurrency import AVFoundation
import CoreGraphics
import CoreVideo
import VideoToolbox

/// Renders one frame of a slide with video into an MP4.
///
/// Each video is read at 30 fps, already upright and converted to SDR (Rec. 709).
/// Every output frame goes through `SlideRenderer`. The audio of the first video is copied.
/// The clip is as long as the shortest video.
struct VideoExporter {
    static let fps: Int32 = 30

    let renderer: SlideRenderer
    let part: Int
    let mediaURL: (String) -> URL

    func export(to url: URL, progress: (Double) -> Void) async throws {
        try? FileManager.default.removeItem(at: url)
        let files = orderedVideoFiles()
        let assets = files.map { AVURLAsset(url: mediaURL($0)) }

        var duration = CMTime.positiveInfinity
        for asset in assets {
            let length = try await asset.load(.duration)
            if length.seconds > 0 { duration = CMTimeMinimum(duration, length) }
        }
        if !duration.isNumeric { duration = CMTime(value: 3, timescale: 1) }

        // Readers
        var sources: [VideoSource] = []
        for (file, asset) in zip(files, assets) {
            sources.append(try await VideoSource(file: file, asset: asset, duration: duration))
        }
        let audio = try await AudioSource(assets: assets, duration: duration)

        // Writer
        let width = renderer.pixelWidth
        let height = renderer.pixelHeight
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let codec: AVVideoCodecType = max(width, height) > 4096 ? .hevc : .h264
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 20_000_000],
            AVVideoColorPropertiesKey: Self.rec709,
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if audio != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: AudioSource.sampleRate,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000,
            ])
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(Int((duration.seconds * Double(Self.fps)).rounded(.down)), 1)
        for index in 0..<frameCount {
            try Task.checkCancellation()
            let time = CMTime(value: CMTimeValue(index), timescale: Self.fps)
            for source in sources {
                if let frame = source.frame(at: time) { renderer.images[source.file] = frame }
            }
            // The writer interleaves: while it holds back video, it wants more audio.
            while !videoInput.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
                let fed = if let audio, let audioInput { try audio.feed(until: duration, to: audioInput, writer: writer) } else { false }
                if !fed { try await Task.sleep(for: .milliseconds(2)) }
            }
            guard let pool = adaptor.pixelBufferPool else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            let buffer = try renderFrame(pool: pool, width: width, height: height)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
            if let audio, let audioInput {
                _ = try audio.feed(until: time + CMTime(value: 1, timescale: 2), to: audioInput, writer: writer)
            }
            if index % 10 == 0 { progress(Double(index) / Double(frameCount)) }
        }
        videoInput.markAsFinished()
        if let audio, let audioInput {
            // Past the clip length counts as the end, so this also finishes the input.
            while !audio.finished {
                if try !audio.feed(until: .positiveInfinity, to: audioInput, writer: writer) {
                    try await Task.sleep(for: .milliseconds(2))
                }
            }
        }
        writer.endSession(atSourceTime: duration)
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        progress(1)
    }

    /// Video files in slot order; the first one gives the audio.
    private func orderedVideoFiles() -> [String] {
        var seen = Set<String>()
        return renderer.layout.slide.slots.compactMap { media in
            guard let media, media.kind == .video, seen.insert(media.file).inserted else { return nil }
            return media.file
        }
    }

    private func renderFrame(pool: CVPixelBufferPool, width: Int, height: Int) throws -> CVPixelBuffer {
        var output: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &output)
        guard let buffer = output else { throw CocoaError(.fileWriteUnknown) }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { throw CocoaError(.fileWriteUnknown) }
        renderer.draw(part: part, in: context)
        return buffer
    }

    static let rec709: [String: String] = [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ]
}

/// Frames of one video at 30 fps, upright, SDR.
private final class VideoSource {
    let file: String
    private let reader: AVAssetReader
    private let output: AVAssetReaderVideoCompositionOutput
    private var pending: CMSampleBuffer?
    private var current: CGImage?

    init(file: String, asset: AVURLAsset, duration: CMTime) async throws {
        self.file = file
        let tracks = try await asset.loadTracks(withMediaType: .video)
        var configuration = try await AVVideoComposition.Configuration(for: asset)
        configuration.frameDuration = CMTime(value: 1, timescale: VideoExporter.fps)
        // Converting into Rec. 709 tone-maps HDR clips from the iPhone.
        configuration.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        configuration.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        configuration.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        let composition = AVVideoComposition(configuration: configuration)
        reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: duration)
        output = AVAssetReaderVideoCompositionOutput(videoTracks: tracks, videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.videoComposition = composition
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? CocoaError(.fileReadUnknown) }
    }

    /// Latest frame at or before `time`.
    func frame(at time: CMTime) -> CGImage? {
        while true {
            if pending == nil { pending = output.copyNextSampleBuffer() }
            guard let sample = pending, CMSampleBufferGetPresentationTimeStamp(sample) <= time else { break }
            if let buffer = sample.imageBuffer {
                var image: CGImage?
                VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &image)
                if let image { current = image }
            }
            pending = nil
        }
        return current
    }
}

/// Audio of the first video that has any, decoded to PCM for the AAC writer.
private final class AudioSource {
    static let sampleRate = 48_000

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let duration: CMTime
    private var pending: CMSampleBuffer?

    init?(assets: [AVURLAsset], duration: CMTime) async throws {
        for asset in assets {
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            reader = try AVAssetReader(asset: asset)
            reader.timeRange = CMTimeRange(start: .zero, duration: duration)
            output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: Self.sampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            reader.add(output)
            self.duration = duration
            guard reader.startReading() else { throw reader.error ?? CocoaError(.fileReadUnknown) }
            return
        }
        return nil
    }

    /// All audio up to the clip length is written and the input is marked finished.
    private(set) var finished = false

    /// Appends samples before `time` while the input takes them. Returns whether it appended any.
    ///
    /// Once the audio runs out (or reaches the clip length) it marks the input finished,
    /// otherwise the writer keeps holding back video while it waits for more audio.
    func feed(until time: CMTime, to input: AVAssetWriterInput, writer: AVAssetWriter) throws -> Bool {
        var appended = false
        while !finished, input.isReadyForMoreMediaData {
            guard let sample = next(), CMSampleBufferGetPresentationTimeStamp(sample) < duration else {
                input.markAsFinished()
                finished = true
                break
            }
            guard CMSampleBufferGetPresentationTimeStamp(sample) < time else { break }
            guard input.append(sample) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            pending = nil
            appended = true
        }
        return appended
    }

    private func next() -> CMSampleBuffer? {
        if pending == nil { pending = output.copyNextSampleBuffer() }
        return pending
    }
}
