import DesignSystem
import SwiftUI

/// The wardrobe, as a sheet from home: the hero on top, updated live, and a row of choices per slot.
public struct WardrobeView: View {
    @State private var viewModel: WardrobeViewModel
    private let onClose: () -> Void

    public init(viewModel: WardrobeViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let content):
                    loaded(content)
                case .failed(let message):
                    ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.background)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
        }
        .task { await viewModel.onAppear() }
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    private func loaded(_ content: WardrobeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                HeroAvatar(
                    style: style,
                    size: 200,
                    skin: content.heroSkin.avatarSkin,
                    items: content.gear.map(\.heroItem),
                    medals: content.medalCount
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.s)
                .background {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [style.tint.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 130
                            )
                        )
                        .frame(width: 260, height: 260)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: content.gear)
                .accessibilityHidden(true)
                ForEach(content.slots) { slot in
                    slotView(slot)
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.boss)
                }
                Text(content.footnote)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
    }

    private func slotView(_ slot: WardrobeSlot) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Label(slot.title, systemImage: slot.symbol)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(slot.xpText)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: DSSpacing.s)], spacing: DSSpacing.s) {
                ForEach(slot.options) { option in
                    optionButton(option, slotID: slot.id)
                }
            }
        }
    }

    private func optionButton(_ option: WardrobeOption, slotID: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous)
        return Button {
            Task { await viewModel.select(slotID: slotID, optionID: option.id) }
        } label: {
            VStack(spacing: DSSpacing.xs) {
                if let item = option.item {
                    HeroItemIcon(item: item.heroItem, size: 60)
                        .grayscale(option.isLocked ? 1 : 0)
                        .opacity(option.isLocked ? 0.55 : 1)
                }
                HStack(spacing: DSSpacing.xs) {
                    if option.isLocked {
                        Image(systemName: "lock.fill").font(.caption)
                    }
                    Text(option.title)
                        .font(DSFont.subheadline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .foregroundStyle(DSColor.textPrimary)
                if let detail = option.detail {
                    Text(detail)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .monospacedDigit()
                }
                if let progress = option.progress {
                    ProgressView(value: progress)
                        .tint(DSColor.xp)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, DSSpacing.s)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.surface, in: shape)
            .overlay { shape.strokeBorder(DSColor.accent, lineWidth: option.isSelected ? 2.5 : 0) }
            .contentShape(shape)
            .opacity(option.isLocked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(option.isLocked)
        .accessibilityAddTraits(option.isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: option.isSelected)
    }
}
