import DesignSystem
import PhotosUI
import SwiftUI

/// Texts for picking a photo.
public struct PhotoLabels: Equatable, Sendable {
    public let addPhoto: String
    public let takePhoto: String
    public let changePhoto: String
    public let removePhoto: String
}

/// A photo for an entry: buttons to add one (library or camera), or a preview of the one it will have, with a menu
/// to change or remove it. Used for legendary moments and for the journal on every card.
struct JournalPhotoField: View {
    @Binding var photo: MomentPhotoEdit
    /// The photo already stored with the entry, shown while `photo` is `.keep`.
    let storedPhotoID: String?
    let labels: PhotoLabels
    let loader: PhotoLoader

    @State private var pickedItem: PhotosPickerItem?
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false

    var body: some View {
        content
            // Presented from the field itself: a picker inside the menu would close with the menu and never appear.
            .photosPicker(isPresented: $isShowingLibrary, selection: $pickedItem, matching: .images)
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

    /// The photo as it will be after saving: a newly chosen one, the stored one, or none.
    @ViewBuilder private var content: some View {
        switch photo {
        case .replace(let data):
            preview(.data(data))
        case .keep:
            if let storedPhotoID {
                preview(.stored(storedPhotoID))
            } else {
                buttons
            }
        default:
            buttons
        }
    }

    private func preview(_ source: WholePhoto.Source) -> some View {
        WholePhoto(source: source, loader: loader)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    Button(labels.changePhoto, systemImage: "photo.on.rectangle") { isShowingLibrary = true }
                    if canUseCamera {
                        Button(labels.takePhoto, systemImage: "camera") { isShowingCamera = true }
                    }
                    Button(labels.removePhoto, systemImage: "trash", role: .destructive) { photo = .remove }
                } label: {
                    Label(labels.changePhoto, systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .padding(DSSpacing.s)
            }
    }

    private var buttons: some View {
        HStack(spacing: DSSpacing.s) {
            Button {
                isShowingLibrary = true
            } label: {
                Label(labels.addPhoto, systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            if canUseCamera {
                Button {
                    isShowingCamera = true
                } label: {
                    Label(labels.takePhoto, systemImage: "camera")
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
