import DesignSystem
import SwiftUI

/// Every world as a stop on a path: visited, current ("you are here") and ahead, each open (ADR-0061 §3). A tap opens
/// a world on a flat display; below a fold it shows the world above it instead (ADR-0061 §4).
struct WorldMapPath: View {
    let map: WorldMapContent
    /// The world marked on the path and "selected" for VoiceOver: the one home shows, or the one above the fold.
    let markedID: String?
    let onTap: (String) -> Void
    /// The numbered marker grows with its number; the path under it stays centred.
    @ScaledMetric(relativeTo: .headline) private var markerSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(map.worlds.enumerated()), id: \.element.id) { index, world in
                stop(world, isLast: index == map.worlds.count - 1)
            }
        }
    }

    private func stop(_ world: WorldMapItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            VStack(spacing: 0) {
                WorldMarker(world: world, size: markerSize)
                if !isLast {
                    Rectangle()
                        .fill(DSColor.textSecondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: markerSize)
            Button {
                onTap(world.id)
            } label: {
                card(world)
            }
            .buttonStyle(.plain)
            .padding(.bottom, DSSpacing.m)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func card(_ world: WorldMapItem) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
        let isMarked = world.id == markedID
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            WorldAgesAndTag(world: world)
            Text(world.title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text(world.tagline)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            WorldLines(world: world)
                .padding(.top, DSSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: shape)
        .overlay { shape.strokeBorder(world.tint, lineWidth: isMarked ? 2 : 0) }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isMarked ? .isSelected : [])
    }
}

/// A world's numbered marker: its number for every world, none locked.
struct WorldMarker: View {
    let world: WorldMapItem
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(world.tint.gradient)
            Text(verbatim: "\(world.number)").font(DSFont.headline)
        }
        .foregroundStyle(DSColor.onTint)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A world's ages, with its tag beside them, or under them at the accessibility sizes, where "months" would break
/// mid-word.
struct WorldAgesAndTag: View {
    let world: WorldMapItem

    var body: some View {
        AdaptiveStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
            Text(world.ageRange)
                .font(DSFont.caption)
                .foregroundStyle(world.tint)
            Spacer(minLength: 0)
            if let tag = world.tag {
                Text(tag)
                    .font(DSFont.caption)
                    .padding(.horizontal, DSSpacing.s)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(world.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(world.tint)
            }
        }
    }
}

/// When a world ahead is ideal, then what was kept there, each on a line of its own.
struct WorldLines: View {
    let world: WorldMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let idealLine = world.idealLine {
                Label(idealLine, systemImage: "sparkles")
            }
            if let progress = world.progress {
                Label(progress, systemImage: "checkmark.circle")
            }
        }
        .font(DSFont.caption)
        .foregroundStyle(DSColor.textSecondary)
    }
}

extension WorldMapItem {
    var tint: Color {
        switch status {
        case .current: DSColor.accent
        case .visited: DSColor.xp
        case .ahead: DSColor.textSecondary
        }
    }
}
