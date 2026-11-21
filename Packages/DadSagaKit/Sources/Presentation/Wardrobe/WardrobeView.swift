import DesignSystem
import HeroArt
import SwiftUI

/// The wardrobe, pushed from Settings (ADR-0044): the hero on top, updated live, and a row of choices per slot. On an
/// iPhone Duo half-open like a laptop the hero stands above the fold and the choices lie below it (ADR-0043).
public struct WardrobeView: View {
    @State private var viewModel: WardrobeViewModel
    /// Grows with the text, so at the accessibility sizes an item gets a row of its own instead of a name cut short.
    @ScaledMetric(relativeTo: .subheadline) private var optionMinimumWidth: CGFloat = 120

    public init(viewModel: WardrobeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
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
        .task { await viewModel.onAppear() }
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    private func loaded(_ content: WardrobeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return ReadAndActPanes(
            alignment: .leading, spacing: DSSpacing.l, flatTitle: .inline, column: WardrobeColumn()
        ) { _ in
            HeroAvatar(
                style: style,
                size: 200,
                skin: content.heroSkin.avatarSkin,
                features: content.heroAppearance.avatarFeatures,
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
            .motion(.spring(response: 0.35, dampingFraction: 0.75), value: content.gear)
            .accessibilityHidden(true)
        } acting: { _ in
            ForEach(content.slots) { slot in
                slotView(slot)
            }
            SheetError(message: viewModel.errorMessage)
            Text(content.footnote)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
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
            let columns = [GridItem(.adaptive(minimum: optionMinimumWidth), spacing: DSSpacing.s)]
            LazyVGrid(columns: columns, spacing: DSSpacing.s) {
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
                        Image(systemName: "lock.fill").font(DSFont.caption)
                    }
                    Text(option.title)
                        .font(DSFont.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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

/// The wardrobe's column.
private struct WardrobeColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
    }
}
