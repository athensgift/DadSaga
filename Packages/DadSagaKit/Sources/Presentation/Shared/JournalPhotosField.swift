import DesignSystem
import PhotosUI
import SwiftUI

/// An entry's photos while a sheet is open (ADR-0042 §3). With none: "Add photos" and the camera. With some: the
/// cover whole, then a row of squares, the cover first and marked, and a "+" while there is room. A tap opens a photo
/// full screen; each square's menu, and the same VoiceOver actions, make it the cover or remove it.
struct JournalPhotosField: View {
    @Binding var photos: PhotoDrafts
    /// The entry, for VoiceOver in the viewer, e.g. "👣 First steps".
    let entry: String
    let labels: PhotoLabels
    let loader: PhotoLoader
    /// `false` while the cover is drawn elsewhere: above the fold of a half-open iPhone Duo (ADR-0043).
    var showsCover = true

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false
    @State private var viewer: PhotoViewerContent?
    /// Picked photos the last pick couldn't open. A note for the dad, not part of the entry: it never counts as a
    /// change to save, and it goes with the dad's next change to the photos (`change`).
    @State private var unreadCount = 0

    static let squareSize: CGFloat = 64

    var body: some View {
        content
            // Presented from the field itself: a picker inside a menu would close with the menu and never appear.
            .photosPicker(
                isPresented: $isShowingLibrary,
                selection: $pickedItems,
                maxSelectionCount: max(photos.remaining, 1),
                selectionBehavior: .ordered,
                matching: .images,
                // A compatible JPEG or HEIC, never a RAW or ProRAW original of tens of megabytes.
                preferredItemEncoding: .compatible
            )
            // Cancelled with the field: a sheet closed mid-load never writes into the next one.
            .task(id: pickedItems) { await load(pickedItems) }
            .photoViewer($viewer, loader: loader)
            .onChange(of: unreadCount) { _, unread in
                // Focus goes back to the field when the picker closes; VoiceOver hears the note as it appears.
                guard unread > 0 else { return }
                AccessibilityNotification.Announcement(labels.couldNotOpen(unread)).post()
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { data in
                    if let data { change { $0.append([data]) } }
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            #endif
    }

    @ViewBuilder private var content: some View {
        if let cover = photos.items.first {
            VStack(alignment: .leading, spacing: DSSpacing.s) {
                if showsCover {
                    JournalCover(source: cover.source, loader: loader) { open(at: 0) }
                        .overlay(alignment: .bottomTrailing) { coverMenu(cover) }
                }
                strip
                if photos.isFull {
                    Text(labels.limitReached)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                unreadNote
            }
        } else if photos.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: Self.squareSize)
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.s) {
                addButtons
                unreadNote
            }
        }
    }

    /// Says how many picked photos couldn't be opened, and what to try, instead of leaving them out without a word.
    @ViewBuilder private var unreadNote: some View {
        if unreadCount > 0 {
            Label(labels.couldNotOpen(unreadCount), systemImage: "exclamationmark.triangle")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var strip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DSSpacing.s) {
                ForEach(Array(photos.items.enumerated()), id: \.element.id) { index, photo in
                    square(photo, at: index)
                }
                if photos.isLoading {
                    ProgressView()
                        .frame(width: Self.squareSize, height: Self.squareSize)
                } else if !photos.isFull {
                    addMenu
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func square(_ photo: PhotoDraft, at index: Int) -> some View {
        let isCover = index == 0
        let shape = RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous)
        return Button { open(at: index) } label: {
            SquarePhoto(source: photo.source, loader: loader) { DSColor.surface }
                .frame(width: Self.squareSize, height: Self.squareSize)
                .clipShape(shape)
                .overlay { if isCover { shape.strokeBorder(DSColor.legendary, lineWidth: 2.5) } }
                .overlay(alignment: .bottomLeading) {
                    if isCover {
                        Image(systemName: "star.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DSColor.onTint)
                            .padding(4)
                            .background(DSColor.legendary, in: Circle())
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isCover {
                Button(labels.makeCover, systemImage: "star") { change { $0.makeCover(id: photo.id) } }
            }
            Button(labels.remove, systemImage: "trash", role: .destructive) { change { $0.remove(id: photo.id) } }
        }
        .accessibilityLabel(isCover ? label(for: index) + ", " + labels.cover : label(for: index))
        .accessibilityActions {
            if !isCover {
                Button(labels.makeCover) { change { $0.makeCover(id: photo.id) } }
            }
            Button(labels.remove) { change { $0.remove(id: photo.id) } }
        }
    }

    /// A visible way to remove the cover, as the field had before; the squares' menus hold the same and more.
    private func coverMenu(_ cover: PhotoDraft) -> some View {
        Menu {
            Button(labels.remove, systemImage: "trash", role: .destructive) { change { $0.remove(id: cover.id) } }
        } label: {
            Label(labels.remove, systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.glass)
        .padding(DSSpacing.s)
        // The cover's square offers the same action to VoiceOver.
        .accessibilityHidden(true)
    }

    /// The "+" after the squares: the library, or the camera when there is one.
    @ViewBuilder private var addMenu: some View {
        let label = Image(systemName: "plus")
            .font(DSFont.headline)
            .frame(width: Self.squareSize, height: Self.squareSize)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
        if canUseCamera {
            Menu {
                Button(labels.addPhotos, systemImage: "photo.on.rectangle") { isShowingLibrary = true }
                Button(labels.takePhoto, systemImage: "camera") { isShowingCamera = true }
            } label: { label }
                .accessibilityLabel(labels.addPhotos)
        } else {
            Button { isShowingLibrary = true } label: { label }
                .buttonStyle(.plain)
                .accessibilityLabel(labels.addPhotos)
        }
    }

    private var addButtons: some View {
        HStack(spacing: DSSpacing.s) {
            Button {
                isShowingLibrary = true
            } label: {
                Label(labels.addPhotos, systemImage: "photo.badge.plus")
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

    /// A change the dad makes to the photos; the note about photos that couldn't be opened goes with it.
    private func change(_ edit: (inout PhotoDrafts) -> Void) {
        unreadCount = 0
        edit(&photos)
    }

    private func label(for index: Int) -> String {
        labels.viewer.photoLabel(number: index + 1, of: photos.items.count, entry: entry)
    }

    private func open(at index: Int) {
        viewer = labels.viewer.content(entry: entry, photos: photos.items.map(\.source), startingAt: index)
    }

    /// Loads the picked photos side by side, keeping the order they were tapped in, and adds the ones the app can read:
    /// anything else would fail when the entry is saved.
    private func load(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        change { $0.startLoading(items.count) }
        let loaded = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask { (index, try? await item.loadTransferable(type: Data.self)) }
            }
            var results = [Data?](repeating: nil, count: items.count)
            for await (index, data) in group {
                results[index] = data
            }
            return results
        }
        // Given up with the field (its sheet closed): nothing is added, and nothing waits any longer.
        guard !Task.isCancelled else {
            photos.finishLoading()
            pickedItems = []
            return
        }
        let readable = loaded.compactMap(\.self).filter(DecodedImage.isImage)
        unreadCount = photos.finishLoading(readable, picked: items.count)
        pickedItems = []
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
