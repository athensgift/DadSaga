import SwiftUI

extension View {
    /// `animation`, or none with Reduce Motion on: things then appear in place instead of springing or sliding in.
    func motion<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MotionUnlessReduced(animation: animation, value: value))
    }
}

private struct MotionUnlessReduced<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
