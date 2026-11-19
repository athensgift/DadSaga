import SwiftUI

extension EnvironmentValues {
    /// Whether cheers and celebrations tap the iPhone. Set once at the root from the dad's preferences (ADR-0030).
    @Entry public var isHapticsEnabled = true
}
