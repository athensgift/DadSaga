import SwiftUI

/// Hair by stage and gender, centred on the head.
struct ChildHair: View {
    /// Hair that hangs behind the head (ponytails, pigtails) is drawn before the head; the rest after it.
    enum Layer { case back, front }

    let stage: ChildAvatar.Stage
    let gender: ChildAvatar.Gender
    let layer: Layer
    let headRadius: CGFloat
    let sway: Double
    @Environment(\.avatarSkin) private var skin

    var body: some View {
        switch layer {
        case .back: back
        case .front: front
        }
    }

    @ViewBuilder private var back: some View {
        let radius = headRadius
        switch (stage, gender) {
        case (.preschooler, .girl):
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(skin.hair).frame(width: 9, height: 18)
                    .rotationEffect(.degrees(side * (25 + sway)), anchor: .top)
                    .offset(x: side * (radius + 3), y: -2)
            }
        case (.kid, .girl):
            Capsule().fill(skin.hair).frame(width: 12, height: 32)
                .rotationEffect(.degrees(28 + sway), anchor: .top)
                .offset(x: radius + 2, y: -radius * 0.2)
        default:
            EmptyView()
        }
    }

    private var front: some View {
        let radius = headRadius
        return ZStack {
            switch (stage, gender) {
            case (.baby, .boy):
                curl.offset(y: -radius + 1)
            case (.baby, .girl):
                curl.offset(y: -radius + 1)
                bow.offset(x: radius * 0.55, y: -radius * 0.7)
            case (.toddler, .boy):
                cap(radius: radius, depth: 0.6)
                ForEach([-5.0, 0.0, 5.0], id: \.self) { offsetX in
                    Capsule().fill(skin.hair).frame(width: 4, height: 8)
                        .rotationEffect(.degrees(offsetX * 3))
                        .offset(x: offsetX, y: -radius - 2)
                }
            case (.toddler, .girl):
                cap(radius: radius, depth: 0.6)
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle().fill(skin.hair).frame(width: 11, height: 11).offset(x: side * (radius + 2), y: -radius * 0.6)
                }
            case (.preschooler, .boy), (.kid, .boy):
                cap(radius: radius, depth: stage == .kid ? 0.9 : 0.75)
                Capsule().fill(skin.hair).frame(width: radius * 1.1, height: 7)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -3, y: -radius * 0.62)
            case (.preschooler, .girl):
                cap(radius: radius, depth: 0.8)
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle().fill(DSColor.legendary).frame(width: 4, height: 4).offset(x: side * (radius + 1), y: -radius * 0.45)
                }
            case (.kid, .girl):
                cap(radius: radius, depth: 0.9)
                Capsule().fill(DSColor.boss).frame(width: 9, height: 4).offset(x: radius * 0.7, y: -radius * 0.55)
            }
        }
    }

    private var curl: some View {
        Circle()
            .trim(from: 0.1, to: 0.8)
            .stroke(skin.hair, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 8, height: 8)
    }

    private var bow: some View {
        HStack(spacing: -1) {
            Image(systemName: "triangle.fill").rotationEffect(.degrees(90))
            Image(systemName: "triangle.fill").rotationEffect(.degrees(-90))
        }
        .font(.system(size: 6))
        .foregroundStyle(DSColor.boss)
    }

    /// Hair covering the top of the head; `depth` is how far down the sides it reaches (0...1 of the radius).
    private func cap(radius: CGFloat, depth: CGFloat) -> some View {
        Circle()
            .fill(skin.hair)
            .frame(width: radius * 2 + 3, height: radius * 2 + 3)
            .mask(alignment: .top) { Rectangle().frame(height: radius * (0.55 + depth * 0.45)) }
    }
}
