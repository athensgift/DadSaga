import DesignSystem
import SwiftUI

/// A date picker with its label in a card row: side by side, or the date under its label at the accessibility
/// text sizes, where the system's own label would be squeezed out of sight.
struct DateRow: View {
    let label: String
    @Binding var date: Date
    let range: ClosedRange<Date>

    var body: some View {
        AdaptiveStack(spacing: DSSpacing.s) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The picker keeps the label for VoiceOver; read it once.
                .accessibilityHidden(true)
            DatePicker(label, selection: $date, in: range, displayedComponents: .date)
                .labelsHidden()
        }
    }
}
