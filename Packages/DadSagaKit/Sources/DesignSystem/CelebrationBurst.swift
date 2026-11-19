import SwiftUI

/// Sparkles that fly out from the centre once and fade, behind a celebration badge.
/// Draws nothing under Reduce Motion: the badge alone carries the message there.
public struct CelebrationBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    private let color: Color
    private let sparkles: Int
    private let radius: CGFloat
    private let delay: Double

    /// - Parameters:
    ///   - color: the sparkles' colour, e.g. `DSColor.legendary` for a level-up.
    ///   - sparkles: how many fly out; more for bigger moments.
    ///   - radius: how far they fly from the centre.
    ///   - delay: seconds to wait first, e.g. for a sheet to finish closing over it.
    public init(color: Color, sparkles: Int = 12, radius: CGFloat = 120, delay: Double = 0) {
        self.color = color
        self.sparkles = sparkles
        self.radius = radius
        self.delay = delay
    }

    public var body: some View {
        if !reduceMotion {
            BurstFrame(progress: progress, color: color, sparkles: sparkles, radius: radius)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                // Started in its own transaction after the delay: an animation the parent attaches to the moment the
                // burst appears (e.g. the badge's spring) would otherwise replace this one and its delay.
                .task {
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
                }
        }
    }
}

/// One frame of the burst. Animatable, so SwiftUI redraws it at every step of `progress`: the sparkles fade in and
/// out again, which interpolating only the start and end values (both invisible) would skip.
private struct BurstFrame: View, @MainActor Animatable {
    var progress: Double
    let color: Color
    let sparkles: Int
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Fades in over the first tenth, holds, then fades out over the last 40 %.
    private var visibility: Double {
        progress < 0.6 ? min(progress * 10, 1) : (1 - progress) / 0.4
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.5 * visibility), lineWidth: 3)
                .frame(width: radius * 2 * progress, height: radius * 2 * progress)
            ForEach(0..<sparkles, id: \.self) { index in
                sparkle(index)
            }
        }
    }

    private func sparkle(_ index: Int) -> some View {
        let angle = Double(index) / Double(sparkles) * 2 * .pi
        // Alternate near and far sparkles so the burst does not read as a perfect ring.
        let reach = radius * (index.isMultiple(of: 2) ? 1 : 0.72) * progress
        let size: CGFloat = index.isMultiple(of: 2) ? 14 : 9
        return Sparkle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(0.4 + 0.8 * (1 - abs(progress - 0.4)))
            .rotationEffect(.degrees(90 * progress))
            .offset(x: cos(angle) * reach, y: sin(angle) * reach)
            .opacity(visibility)
    }
}
