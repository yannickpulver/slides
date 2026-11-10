@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
@testable import SlidesCore

/// Test media generated on the fly.
enum Fixtures {
    static func tempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "slides-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Solid image of one color.
    static func image(width: Int, height: Int, color: RGB) -> CGImage {
        let context = SlideRenderer.makeContext(width: width, height: height)!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// Left half red, right half blue.
    static func halves(width: Int, height: Int) -> CGImage {
        let context = SlideRenderer.makeContext(width: width, height: height)!
        context.setFillColor(RGB(r: 1, g: 0, b: 0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(RGB(r: 0, g: 0, b: 1).cgColor)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return context.makeImage()!
    }

    static func writePNG(_ image: CGImage, named name: String, in folder: URL) -> URL {
        let url = folder.appending(path: name)
        try! Exporter.writePNG(image, to: url)
        return url
    }

    /// A green video of `seconds` at 30 fps, optionally with a 440 Hz tone.
    static func video(seconds: Double, width: Int = 320, height: Int = 240, audio: Bool = false, in folder: URL) async throws -> URL {
        let url = folder.appending(path: "clip-\(UUID().uuidString.prefix(4)).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        let sampleRate = 44_100.0
        var audioInput: AVAssetWriterInput?
        if audio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1,
            ])
            writer.add(input)
            audioInput = input
        }
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        var audioBuffers: [CMSampleBuffer] = []
        if audioInput != nil {
            let chunk = 4410
            var asbd = AudioStreamBasicDescription(
                mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0
            )
            var format: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
            for start in stride(from: 0, to: Int(seconds * sampleRate), by: chunk) {
                let samples = (0..<chunk).map { Int16(sin(Double(start + $0) * 2 * .pi * 440 / sampleRate) * 8000) }
                var block: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: chunk * 2, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: chunk * 2, flags: 0, blockBufferOut: &block)
                samples.withUnsafeBytes { _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: chunk * 2) }
                var buffer: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: format!, sampleCount: chunk, presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(sampleRate)), packetDescriptions: nil, sampleBufferOut: &buffer)
                audioBuffers.append(buffer!)
            }
        }
        func feedAudio(until time: CMTime) {
            guard let audioInput else { return }
            while let first = audioBuffers.first, audioInput.isReadyForMoreMediaData,
                  CMSampleBufferGetPresentationTimeStamp(first) <= time {
                audioInput.append(first)
                audioBuffers.removeFirst()
                if audioBuffers.isEmpty { audioInput.markAsFinished() }
            }
        }

        let frames = Int(seconds * 30)
        for index in 0..<frames {
            let time = CMTime(value: CMTimeValue(index), timescale: 30)
            feedAudio(until: time + CMTime(value: 1, timescale: 4))
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error! }
                feedAudio(until: .positiveInfinity)
                try await Task.sleep(for: .milliseconds(1))
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            CVPixelBufferLockBaseAddress(buffer!, [])
            let base = CVPixelBufferGetBaseAddress(buffer!)!.assumingMemoryBound(to: UInt8.self)
            let rowBytes = CVPixelBufferGetBytesPerRow(buffer!)
            for y in 0..<height {
                for x in 0..<width {
                    let p = base + y * rowBytes + x * 4
                    p[0] = 0; p[1] = 200; p[2] = 0; p[3] = 255 // BGRA green
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            adaptor.append(buffer!, withPresentationTime: time)
        }
        input.markAsFinished()
        while !audioBuffers.isEmpty, let audioInput {
            feedAudio(until: .positiveInfinity)
            if !audioBuffers.isEmpty { try await Task.sleep(for: .milliseconds(1)) }
        }
        await writer.finishWriting()
        return url
    }
}

extension CGImage {
    /// RGBA of one pixel, 0...255, y from the top.
    func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        let context = SlideRenderer.makeContext(width: 1, height: 1)!
        context.draw(self, in: CGRect(x: -x, y: -(height - 1 - y), width: width, height: height))
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        return (Int(data[0]), Int(data[1]), Int(data[2]))
    }
}
