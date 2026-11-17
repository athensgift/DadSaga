import DesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The weekly reminder settings, as a sheet from home (ADR-0024).
public struct ReminderSettingsView: View {
    @State private var viewModel: ReminderSettingsViewModel
    @Environment(\.openURL) private var openURL
    private let onClose: () -> Void

    public init(viewModel: ReminderSettingsViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoaded {
                    form
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.background)
            .navigationTitle(viewModel.labels.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
        }
        .task { await viewModel.onAppear() }
    }

    private var form: some View {
        let labels = viewModel.labels
        return Form {
            Section {
                Toggle(labels.toggle, isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { value in Task { await viewModel.setEnabled(value) } }
                ))
                if viewModel.isEnabled {
                    Picker(labels.day, selection: Binding(
                        get: { viewModel.weekday },
                        set: { value in Task { await viewModel.setWeekday(value) } }
                    )) {
                        ForEach(viewModel.weekdays) { Text($0.name).tag($0.id) }
                    }
                    DatePicker(labels.time, selection: timeBinding, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text(labels.explanation)
            }
            if let denied = viewModel.deniedMessage {
                Section {
                    Text(denied)
                        .foregroundStyle(DSColor.textSecondary)
                    #if canImport(UIKit)
                    Button(labels.openSettings) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    #endif
                }
            }
        }
        .font(DSFont.body)
        .scrollContentBackground(.hidden)
        .animation(.default, value: viewModel.isEnabled)
        .animation(.default, value: viewModel.deniedMessage)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: viewModel.hour, minute: viewModel.minute, second: 0, of: .now
                ) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                Task { await viewModel.setTime(hour: parts.hour ?? 10, minute: parts.minute ?? 0) }
            }
        )
    }
}
