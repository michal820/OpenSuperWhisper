import Accelerate
import AVFoundation
import SwiftUI

/// Live microphone loudness for the recording indicator's waveform, fed from
/// the recording tap.
@MainActor
final class AudioLevelMeter: ObservableObject {
    static let shared = AudioLevelMeter()
    /// Number of recent levels kept, newest last: about one second at ~30 fps.
    static let historyCount = 30

    /// Room noise on a laptop mic sits just below this, so silence shows flat bars.
    private static let floorDecibels: Float = -55
    /// The full-bar loudness follows the speaker's recent peaks within this
    /// range, so a quiet mic still fills the bars and a loud one doesn't clip.
    private static let ceilingRange: ClosedRange<Float> = -35 ... -10
    private static let ceilingFallPerUpdate: Float = 0.1
    /// Bars rise at once but fall gradually, so they don't flicker between words.
    private static let releasePerUpdate: CGFloat = 0.8

    @Published private(set) var levels = [CGFloat](repeating: 0, count: historyCount)
    private var ceiling = ceilingRange.lowerBound

    private init() {}

    func reset() {
        levels = [CGFloat](repeating: 0, count: Self.historyCount)
        ceiling = Self.ceilingRange.lowerBound
    }

    func push(decibels: Float) {
        ceiling = min(max(decibels, ceiling - Self.ceilingFallPerUpdate, Self.ceilingRange.lowerBound),
                      Self.ceilingRange.upperBound)
        let level = CGFloat(min(max((decibels - Self.floorDecibels) / (ceiling - Self.floorDecibels), 0), 1))
        let previous = levels.last ?? 0
        levels.removeFirst()
        levels.append(max(level, previous * Self.releasePerUpdate))
    }

    /// RMS of the loudest channel in dBFS. The loudest channel, because
    /// multi-channel interfaces often leave channel 0 silent.
    nonisolated static func decibels(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return -160 }
        let channelCount = buffer.format.isInterleaved ? 1 : Int(buffer.format.channelCount)
        var peak: Float = 0
        for channel in 0..<channelCount {
            var rms: Float = 0
            vDSP_rmsqv(channels[channel], buffer.stride, &rms, vDSP_Length(buffer.frameLength))
            peak = max(peak, rms)
        }
        return 20 * log10(max(peak, 1e-8))
    }
}

/// Scrolling bar waveform of the most recent levels, newest on the right,
/// shaded from faded lavender (older) to pink (newest). Heights ease between
/// updates.
struct WaveformView: View {
    @ObservedObject var meter = AudioLevelMeter.shared
    var scale: CGFloat = 1

    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 2.5

    var body: some View {
        let count = CGFloat(AudioLevelMeter.historyCount)
        LinearGradient(
            colors: [IndicatorStyle.lavender.opacity(0.4), IndicatorStyle.lavender, IndicatorStyle.pink],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask {
            HStack(spacing: Self.barSpacing * scale) {
                ForEach(meter.levels.indices, id: \.self) { index in
                    Capsule()
                        .frame(width: Self.barWidth * scale, height: (2 + 18 * meter.levels[index]) * scale)
                }
            }
        }
        .frame(width: (count * Self.barWidth + (count - 1) * Self.barSpacing) * scale, height: 22 * scale)
        .animation(.easeOut(duration: 0.1), value: meter.levels)
    }
}
