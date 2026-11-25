import DesignSystem
import SwiftUI

/// A screen that couldn't load: what happened, and a button that loads it again.
public struct LoadFailure: Equatable, Sendable {
    public let message: String
    public let retryTitle: String

    public init(message: String, retryTitle: String) {
        self.message = message
        self.retryTitle = retryTitle
    }
}

struct LoadFailureView: View {
    let failure: LoadFailure
    let onRetry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label(failure.message, systemImage: "exclamationmark.triangle")
        } actions: {
            Button(failure.retryTitle) { Task { await onRetry() } }
                .buttonStyle(.glass)
        }
    }
}
