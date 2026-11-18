import DesignSystem
import SwiftUI

/// Capture a legendary moment, or edit one: which first, when it happened, a few words and a photo.
struct MomentSheet: View {
    let capture: MomentCapture
    let errorMessage: String?
    let isSaving: Bool
    let loader: PhotoLoader
    let onSave: (_ firstID: String, _ date: Date, _ note: String, _ photo: MomentPhotoEdit) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var selectedID: String?
    @State private var date: Date
    @State private var note: String
    @State private var photo: MomentPhotoEdit = .keep
    @State private var isConfirmingDelete = false

    init(
        capture: MomentCapture,
        errorMessage: String?,
        isSaving: Bool,
        loader: @escaping PhotoLoader,
        onSave: @escaping (_ firstID: String, _ date: Date, _ note: String, _ photo: MomentPhotoEdit) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.capture = capture
        self.errorMessage = errorMessage
        self.isSaving = isSaving
        self.loader = loader
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _date = State(initialValue: capture.editing?.date ?? capture.latestDate)
        _note = State(initialValue: capture.editing?.note ?? "")
        // When editing there is only one first, and it is the moment's own.
        _selectedID = State(initialValue: capture.editing == nil ? nil : capture.options.first?.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.m) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: DSSpacing.s)], spacing: DSSpacing.s) {
                        ForEach(capture.options) { option in
                            optionButton(option)
                        }
                    }
                    JournalPhotoField(
                        photo: $photo,
                        storedPhotoID: capture.editing?.photoID,
                        labels: capture.labels.photo,
                        loader: loader
                    )
                    details
                    if let errorMessage {
                        Text(errorMessage)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.boss)
                    }
                    if capture.editing != nil {
                        Button(capture.labels.delete, systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                            .frame(maxWidth: .infinity)
                            .padding(.top, DSSpacing.s)
                    }
                }
                .frame(maxWidth: readableWidth)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DSColor.background)
            .navigationTitle(capture.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let selectedID { onSave(selectedID, date, note, photo) }
                    }
                    .disabled(selectedID == nil || isSaving)
                    .accessibilityLabel(capture.saveTitle)
                }
            }
            .confirmationDialog(capture.labels.deleteConfirmation, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button(capture.labels.delete, role: .destructive, action: onDelete)
                Button(capture.labels.cancel, role: .cancel) {}
            }
        }
    }

    // MARK: Details

    private var details: some View {
        VStack(spacing: 0) {
            DatePicker(
                capture.dateLabel,
                selection: $date,
                in: capture.earliestDate...capture.latestDate,
                displayedComponents: .date
            )
            .padding(.horizontal, DSSpacing.m)
            .frame(minHeight: 50)
            Divider().padding(.leading, DSSpacing.m)
            TextField(capture.notePlaceholder, text: $note, axis: .vertical)
                .lineLimit(2...5)
                .padding(DSSpacing.m)
        }
        .font(DSFont.body)
        .foregroundStyle(DSColor.textPrimary)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }

    private func optionButton(_ option: MomentOption) -> some View {
        let isSelected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous)
        return Button {
            selectedID = option.id
        } label: {
            VStack(spacing: DSSpacing.xs) {
                Text(option.emoji).font(DSFont.emoji)
                Text(option.title)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                Text(option.reward)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.legendary)
            }
            .frame(maxWidth: .infinity)
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
