import DesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
            #if os(iOS)
            CompactDatePicker(label: label, date: $date, range: range)
            #else
            // macOS only builds the package to run its tests.
            DatePicker(label, selection: $date, in: range, displayedComponents: .date)
                .labelsHidden()
            #endif
        }
    }
}

#if os(iOS)
/// iOS's compact date control, as wide as the date it shows.
///
/// Not SwiftUI's `DatePicker`: SwiftUI takes that one's size from its `UIDatePicker` before the picker has laid out
/// the selection, when it still answers with the width of the day it was made on: the real today, in the device's
/// region. The row then changed width from one day to the next (at the largest text sizes it pushed the card with
/// it), and a date longer than today's was cut down to digits. `UIDatePicker` only knows its size after a layout
/// pass in a window, which is too late for SwiftUI, so the size is worked out here, from the date as the picker
/// writes it.
private struct CompactDatePicker: UIViewRepresentable {
    /// The space iOS leaves around the date inside the picker's pill.
    private enum Pill {
        static let side: CGFloat = 12
        static let topAndBottom: CGFloat = 7
    }

    let label: String
    @Binding var date: Date
    let range: ClosedRange<Date>

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = .compact
        picker.datePickerMode = .date
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.date = $date
        picker.calendar = context.environment.calendar
        picker.locale = context.environment.locale
        picker.timeZone = context.environment.timeZone
        picker.minimumDate = range.lowerBound
        picker.maximumDate = range.upperBound
        picker.date = date
        picker.accessibilityLabel = label
        // A new date, language or text size is a new width.
        picker.invalidateIntrinsicContentSize()
    }

    /// The date in the body font, as the picker writes it when it has the room, and the pill around it. With less
    /// room than this the picker falls back to digits, so each side is rounded up to a whole pixel, and one more.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView picker: UIDatePicker, context: Context) -> CGSize? {
        let environment = context.environment
        let written = date.formatted(Date.FormatStyle(
            date: .abbreviated,
            time: .omitted,
            locale: environment.locale,
            calendar: environment.calendar,
            timeZone: environment.timeZone
        ))
        let font = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(
                preferredContentSizeCategory: UIContentSizeCategory(environment.dynamicTypeSize)
            )
        )
        let text = (written as NSString).size(withAttributes: [.font: font])
        // Counted in pixels: a third of a point summed in points can land just under the pixel, and lose it.
        let scale = environment.displayScale
        let width = (text.width * scale).rounded(.up) + 2 * Pill.side * scale + 1
        let height = (text.height * scale).rounded(.up) + 2 * Pill.topAndBottom * scale
        return CGSize(width: width / scale, height: height / scale)
    }

    @MainActor
    final class Coordinator: NSObject {
        var date: Binding<Date>

        init(date: Binding<Date>) {
            self.date = date
        }

        @objc
        func dateChanged(_ picker: UIDatePicker) {
            date.wrappedValue = picker.date
        }
    }
}
#endif
