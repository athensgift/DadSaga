import Foundation

extension String? {
    /// Trimmed, or `nil` when nothing is left.
    var trimmedOrNil: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
