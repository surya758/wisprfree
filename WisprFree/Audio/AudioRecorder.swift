import AVFoundation

/// Captures microphone audio and delivers 16 kHz mono Float32 samples,
/// the format Parakeet expects. Also exports the same samples as WAV
/// for the direct-to-Gemini mode.
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let lock = NSLock()

    static let targetSampleRate: Double = 16_000

    private(set) var isRecording = false

    /// Called on an audio thread with a rough 0…1 loudness per chunk.
    var onLevel: ((Float) -> Void)?

    func start() throws {
        guard !isRecording else { return }
        samples.removeAll(keepingCapacity: true)

        let input = engine.inputNode
        // Route to the user-chosen input device (empty = system default).
        let uid = AppSettings.current.micDeviceUID
        if !uid.isEmpty, let deviceID = AudioDevices.deviceID(forUID: uid),
           let unit = input.audioUnit {
            var id = deviceID
            AudioUnitSetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global,
                0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw WisprError.noMicrophone
        }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        )!
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stops the tap and returns everything captured since start().
    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    private func append(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var fed = false
        var conversionError: NSError?
        converter.convert(to: out, error: &conversionError) { _, outStatus in
            if fed {
                outStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, let channel = out.floatChannelData, out.frameLength > 0 else { return }

        let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()

        if let onLevel {
            let rms = sqrt(chunk.reduce(0) { $0 + $1 * $1 } / Float(max(chunk.count, 1)))
            onLevel(min(1, rms * 12))
        }
    }

    /// Encodes 16 kHz mono Float32 samples as a 16-bit PCM WAV file in memory.
    static func wavData(from samples: [Float]) -> Data {
        let sampleRate = UInt32(targetSampleRate)
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(samples.count * 2)

        var data = Data(capacity: 44 + Int(dataSize))
        func append<T>(_ value: T) {
            withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(channels)
        append(sampleRate)
        append(byteRate)
        append(blockAlign)
        append(bitsPerSample)
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append(Int16(clamped * Float(Int16.max)))
        }
        return data
    }
}
