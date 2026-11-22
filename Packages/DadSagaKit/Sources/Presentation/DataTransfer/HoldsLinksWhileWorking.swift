import SwiftUI

/// While a page is exporting or importing, a link from outside waits, as it does for an editor's unsaved changes
/// (ADR-0050 §4, ADR-0057 §8).
struct HoldsLinksWhileWorking: ViewModifier {
    let isWorking: Bool
    @Environment(UnsavedWork.self) private var unsavedWork: UnsavedWork?
    @Environment(\.unsavedScope) private var scope
    @State private var registration: EditorRegistration?

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(isWorking)
            .onChange(of: isWorking, initial: true) { _, working in
                guard working || registration != nil else { return }
                let registration = registration ?? EditorRegistration()
                self.registration = registration
                registration.report(hasUnsavedChanges: working, in: scope, to: unsavedWork)
            }
    }
}

extension View {
    func holdsLinks(whileWorking isWorking: Bool) -> some View {
        modifier(HoldsLinksWhileWorking(isWorking: isWorking))
    }
}
