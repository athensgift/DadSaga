import DesignSystem
import SwiftUI

/// Every world as a stop on a path: visited, current ("you are here") and locked. Tapping an unlocked world shows its
/// quests on home.
struct WorldMapSheet: View {
    let map: WorldMapContent
    let onSelect: (String) -> Void
    let onClose: () -> Void
    /// The numbered marker grows with its number; the path under it stays centred.
    @ScaledMetric(relativeTo: .headline) private var markerSize: CGFloat = 44

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(map.subtitle)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.bottom, DSSpacing.m)
                    ForEach(Array(map.worlds.enumerated()), id: \.element.id) { index, world in
                        stop(world, isLast: index == map.worlds.count - 1)
                    }
                }
                .frame(maxWidth: readableWidth, alignment: .leading)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(DSColor.background)
            .navigationTitle(map.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
        }
    }

    private func stop(_ world: WorldMapItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            VStack(spacing: 0) {
                marker(world)
                if !isLast {
                    Rectangle()
                        .fill(DSColor.textSecondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: markerSize)
            Button {
                onSelect(world.id)
            } label: {
                card(world)
            }
            .buttonStyle(.plain)
            .disabled(world.status == .locked)
            .padding(.bottom, DSSpacing.m)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func marker(_ world: WorldMapItem) -> some View {
        ZStack {
            Circle().fill(tint(world).gradient)
            if world.status == .locked {
                Image(systemName: "lock.fill").font(DSFont.smallSymbol)
            } else {
                Text(verbatim: "\(world.number)").font(DSFont.headline)
            }
        }
        .foregroundStyle(DSColor.onTint)
        .frame(width: markerSize, height: markerSize)
        .accessibilityHidden(true)
    }

    private func card(_ world: WorldMapItem) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(world.ageRange)
                    .font(DSFont.caption)
                    .foregroundStyle(tint(world))
                Spacer()
                if let tag = world.tag {
                    Text(tag)
                        .font(DSFont.caption)
                        .padding(.horizontal, DSSpacing.s)
                        .padding(.vertical, 2)
                        .background(tint(world).opacity(0.15), in: Capsule())
                        .foregroundStyle(tint(world))
                }
            }
            Text(world.title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text(world.tagline)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Label(world.detail, systemImage: world.status == .locked ? "hourglass" : "checkmark.circle")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.top, DSSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: shape)
        .overlay { shape.strokeBorder(tint(world), lineWidth: world.isShown ? 2 : 0) }
        .contentShape(shape)
        .opacity(world.status == .locked ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(world.isShown ? .isSelected : [])
    }

    private func tint(_ world: WorldMapItem) -> Color {
        switch world.status {
        case .current: DSColor.accent
        case .visited: DSColor.xp
        case .locked: DSColor.textSecondary
        }
    }
}
