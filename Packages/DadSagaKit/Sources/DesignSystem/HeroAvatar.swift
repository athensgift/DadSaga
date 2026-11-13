import SwiftUI

/// The player's hero, drawn in code: no image assets, and every part can animate.
/// Idles (bobbing, breathing, blinking, looking around, swaying gear) and cheers when tapped. Honours Reduce Motion.
public struct HeroAvatar: View {
    public enum Style: Sendable, CaseIterable {
        case knight, mage, ranger

        public var tint: Color {
            switch self {
            case .knight: DSColor.accent
            case .mage: DSColor.heroMage
            case .ranger: DSColor.heroRanger
            }
        }

        var shade: Color {
            switch self {
            case .knight: DSColor.heroKnightShade
            case .mage: DSColor.heroMageShade
            case .ranger: DSColor.heroRangerShade
            }
        }

        /// Gauntlet, sleeve trim or bracer at the wrist.
        var cuff: Color {
            switch self {
            case .knight: DSColor.heroSteel
            case .mage: DSColor.legendary
            case .ranger: DSColor.heroLeather
            }
        }

        var fabric: LinearGradient { heroGradient(tint, shade) }
    }

    private let style: Style
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCheering = false
    @State private var hasAppeared = false

    /// - Parameter size: the avatar's height in points.
    public init(style: Style, size: CGFloat = 200) {
        self.style = style
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            HeroFigure(
                style: style,
                pose: reduceMotion ? .rest : HeroPose(time: context.date.timeIntervalSinceReferenceDate),
                isCheering: isCheering
            )
        }
        .scaleEffect(size / HeroFigure.designSize.height)
        .frame(width: size * HeroFigure.designSize.width / HeroFigure.designSize.height, height: size)
        .scaleEffect(hasAppeared ? 1 : 0.6)
        .opacity(hasAppeared ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: cheer)
        .sensoryFeedback(.impact, trigger: isCheering) { _, cheering in cheering }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { hasAppeared = true }
        }
        .accessibilityAddTraits(.isImage)
    }

    private func cheer() {
        guard !isCheering else { return }
        isCheering = true
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            isCheering = false
        }
    }
}

/// Time-driven idle animation values.
struct HeroPose {
    var bob: CGFloat = 0
    var breath: CGFloat = 1
    var eyeScale: CGFloat = 1
    /// Horizontal pupil offset: the hero glances left and right.
    var look: CGFloat = 0
    var sway: Double = 0
    var glow: Double = 0.5
    /// Angle (radians) of anything orbiting, e.g. the mage's sparkles.
    var orbit: Double = 0
    /// 0...1 flash on the knight's blade.
    var glint: Double = 0

    static let rest = HeroPose()

    init() {}

    init(time: TimeInterval) {
        bob = sin(time * 2.2) * 2.5
        breath = 1 + sin(time * 2.2) * 0.02
        eyeScale = time.truncatingRemainder(dividingBy: 3.6) < 0.14 ? 0.1 : 1
        look = sin(time * 0.7) * 1.2
        sway = sin(time * 1.6) * 4
        glow = 0.5 + 0.5 * sin(time * 3)
        orbit = time * 2
        glint = pow(max(0, sin(time * 1.3)), 12)
    }
}

/// The whole character on a fixed design canvas. `HeroAvatar` scales it to the requested size.
/// Parts are positioned from the canvas centre and layered back to front.
struct HeroFigure: View {
    static let designSize = CGSize(width: 110, height: 160)

    let style: HeroAvatar.Style
    let pose: HeroPose
    let isCheering: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(DSColor.heroInk.opacity(0.15))
                .frame(width: isCheering ? 40 : 58, height: 10)
                .offset(y: 69)
            ZStack {
                HeroBackGear(style: style, sway: pose.sway)
                HeroLegs(style: style)
                HeroTorso(style: style, breath: pose.breath)
                HeroWeapon(style: style, pose: pose)
                HeroArm(style: style, angle: isCheering ? 150 : 8 + pose.sway, holdsShield: style == .knight)
                    .offset(x: -25, y: 14)
                HeroArm(style: style, angle: -12, holdsShield: false)
                    .offset(x: 25, y: 14)
                HeroShoulders(style: style)
                HeroHead(pose: pose, isCheering: isCheering)
                HeroHeadgear(style: style, sway: pose.sway)
            }
            .offset(y: 12 + pose.bob + (isCheering ? -18 : 0))
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: isCheering)
    }
}

/// Top-to-bottom shading used to give flat shapes some volume.
func heroGradient(_ top: Color, _ bottom: Color) -> LinearGradient {
    LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
}

#Preview("Heroes") {
    HStack {
        ForEach(HeroAvatar.Style.allCases, id: \.self) { style in
            HeroAvatar(style: style, size: 200)
        }
    }
    .padding()
    .background(DSColor.background)
}
