import Accelerate
import AVFoundation
import SwiftUI

/// Live microphone loudness for the recording indicator's waveform, fed from
/// the recording tap.
@MainActor
final class AudioLevelMeter: ObservableObject {
    static let shared = AudioLevelMeter()
    static let barCount = 24

    @Published private(set) var levels = [CGFloat](repeating: 0, count: barCount)

    private init() {}

    func reset() {
        levels = [CGFloat](repeating: 0, count: Self.barCount)
    }

    func push(_ level: CGFloat) {
        levels.removeFirst()
        levels.append(level)
    }

    /// RMS of the loudest channel mapped from -50...-10 dBFS (quiet room to
    /// close speech on a laptop mic) to 0...1. The loudest channel, because
    /// multi-channel interfaces often leave channel 0 silent.
    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let channelCount = buffer.format.isInterleaved ? 1 : Int(buffer.format.channelCount)
        var peak: Float = 0
        for channel in 0..<channelCount {
            var rms: Float = 0
            vDSP_rmsqv(channels[channel], buffer.stride, &rms, vDSP_Length(buffer.frameLength))
            peak = max(peak, rms)
        }
        let decibels = 20 * log10(max(peak, 1e-7))
        return CGFloat(min(max((decibels + 50) / 40, 0), 1))
    }
}

/// Scrolling bar waveform of the most recent input levels, newest on the right.
struct WaveformView: View {
    @ObservedObject var meter = AudioLevelMeter.shared

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(meter.levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3, height: 3 + meter.levels[index] * 17)
            }
        }
        .frame(height: 20)
    }
}
