import DesignSystem
import PhotosUI
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
    @State private var pickedItem: PhotosPickerItem?
    @State private var isConfirmingDelete = false
    @State private var isShowingCamera = false

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
                    photoSection
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
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photo = .replace(data)
                }
                pickedItem = nil
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { data in
                if let data { photo = .replace(data) }
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        #endif
    }

    // MARK: Photo

    /// The photo as it will be after saving: a newly chosen one, the stored one, or none.
    @ViewBuilder private var photoSection: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
        switch photo {
        case .replace(let data):
            if let image = Image(imageData: data) {
                photoPreview { image.resizable().scaledToFill() }
            } else {
                photoButtons(shape: shape)
            }
        case .keep where capture.editing?.photoID != nil:
            photoPreview {
                MomentPhoto(photoID: capture.editing?.photoID, loader: loader) { DSColor.surface }
            }
        default:
            photoButtons(shape: shape)
        }
    }

    private func photoPreview(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(capture.labels.changePhoto, systemImage: "photo.on.rectangle")
                    }
                    if canUseCamera {
                        Button(capture.labels.takePhoto, systemImage: "camera") { isShowingCamera = true }
                    }
                    Button(capture.labels.removePhoto, systemImage: "trash", role: .destructive) { photo = .remove }
                } label: {
                    Label(capture.labels.changePhoto, systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .padding(DSSpacing.s)
            }
    }

    private func photoButtons(shape: RoundedRectangle) -> some View {
        HStack(spacing: DSSpacing.s) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label(capture.labels.addPhoto, systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            if canUseCamera {
                Button {
                    isShowingCamera = true
                } label: {
                    Label(capture.labels.takePhoto, systemImage: "camera")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }

    private var canUseCamera: Bool {
        #if os(iOS)
        CameraPicker.isAvailable
        #else
        false
        #endif
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
                Text(option.emoji).font(.system(size: 30))
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

#if os(iOS)
/// The system camera. Hands back JPEG data, or `nil` if the dad cancelled.
private struct CameraPicker: UIViewControllerRepresentable {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onFinish: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
#endif
