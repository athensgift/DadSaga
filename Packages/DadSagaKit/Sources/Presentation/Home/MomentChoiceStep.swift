import DesignSystem
import SwiftUI

/// Step 1 of a new moment: the grid of firsts and when it happened. ✓ records it at once (ADR-0042 §5). The date is
/// asked here, not later: it decides where the moment lands in the timeline and the film. It and the line about step 2
/// sit above the grid, which runs past the screen.
struct MomentChoiceStep: View {
    /// The child's name.
    let title: String
    let choice: MomentChoice
    let errorMessage: String?
    let isSaving: Bool
    let onCapture: (_ firstID: String, _ date: Date) -> Void
    let onClose: () -> Void

    @State private var selectedID: String?
    @State private var date: Date
    /// Grows with the text, so large sizes get fewer, wider tiles instead of words broken mid-word.
    @ScaledMetric(relativeTo: .caption) private var tileMinimumWidth: CGFloat = 104

    init(
        title: String,
        choice: MomentChoice,
        errorMessage: String?,
        isSaving: Bool,
        onCapture: @escaping (_ firstID: String, _ date: Date) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.choice = choice
        self.errorMessage = errorMessage
        self.isSaving = isSaving
        self.onCapture = onCapture
        self.onClose = onClose
        _date = State(initialValue: choice.latestDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                DateRow(label: choice.dateLabel, date: $date, range: earliestDate...choice.latestDate)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                    .padding(.horizontal, DSSpacing.m)
                    .frame(minHeight: 50)
                    .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                Text(choice.nextLine)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                let columns = [GridItem(.adaptive(minimum: max(104, tileMinimumWidth)), spacing: DSSpacing.s)]
                LazyVGrid(columns: columns, spacing: DSSpacing.s) {
                    ForEach(choice.options) { option in
                        optionButton(option)
                    }
                }
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
        .pinnedSheetError(errorMessage)
        .background(DSColor.background)
        .navigationTitle(title)
        // Nor swiped away while it saves: step 2, with the moment's Undo, comes in this sheet.
        .interactiveDismissDisabled(isSaving)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: onClose)
                    // A save under way can't be discarded: it records the moment anyway.
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    if let selectedID { onCapture(selectedID, date) }
                }
                .disabled(selectedID == nil || isSaving)
                .accessibilityLabel(choice.saveTitle)
            }
        }
    }

    /// The chosen first's own earliest day, or the earliest of all while none is chosen.
    private var earliestDate: Date {
        choice.options.first { $0.id == selectedID }?.earliestDate ?? choice.earliestDate
    }

    private func optionButton(_ option: MomentOption) -> some View {
        let isSelected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous)
        return Button {
            selectedID = option.id
            date = option.date(for: date)
        } label: {
            VStack(spacing: DSSpacing.xs) {
                Text(option.emoji).font(DSFont.emoji)
                Text(option.title)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    // Every word of a long first, on as many lines as it takes.
                    .fixedSize(horizontal: false, vertical: true)
            }
            // As tall as the row's tallest, so the tiles in a row line up.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, DSSpacing.s)
            .padding(.horizontal, DSSpacing.xs)
            .background(DSColor.surface, in: shape)
            .overlay { shape.strokeBorder(DSColor.legendary, lineWidth: isSelected ? 2.5 : 0) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}
