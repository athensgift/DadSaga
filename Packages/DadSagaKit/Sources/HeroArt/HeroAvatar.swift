import DesignSystem
import SwiftUI

/// The player's hero, drawn in code: no image assets, and every part can animate.
/// Idles (bobbing, breathing, blinking, looking around, swaying gear) and cheers when tapped. Honours Reduce Motion.
public struct HeroAvatar: View {
    /// The dad archetypes. Each one is a look only.
    public enum Style: Sendable, CaseIterable {
        case hero, cool, strong, smart, chef, fixer
    }

    private let style: Style
    private let size: CGFloat
    private let cheerTrigger: Int
    private let skin: AvatarSkin
    private let features: HeroFeatures
    private let equipment: HeroEquipment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.avatarsAreStill) private var isStill
    @Environment(\.isHapticsEnabled) private var isHapticsEnabled
    @State private var isCheering = false
    @State private var hasAppeared = false

    /// - Parameters:
    ///   - size: the avatar's height in points.
    ///   - cheerTrigger: raise this value to make the hero cheer, as if he had been tapped. Lowering it does nothing.
    ///   - skin: the dad's skin tone.
    ///   - features: the dad's hair, beard and glasses; `nil` is the standard look, with the hair colour of `skin`.
    ///   - items: earned gear to draw; at most one per slot (the last one wins).
    ///   - medals: boss medals on the chest; up to four are drawn.
    public init(
        style: Style,
        size: CGFloat = 200,
        cheerTrigger: Int = 0,
        skin: AvatarSkin = .mediumLight,
        features: HeroFeatures? = nil,
        items: [HeroItem] = [],
        medals: Int = 0
    ) {
        self.style = style
        self.size = size
        self.cheerTrigger = cheerTrigger
        self.skin = skin
        self.features = features ?? HeroFeatures(hairColor: skin.naturalHair)
        equipment = HeroEquipment(items: items, medals: medals)
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion || isStill)) { context in
            HeroFigure(
                style: style,
                pose: reduceMotion || isStill ? .rest : HeroPose(time: context.date.timeIntervalSinceReferenceDate),
                isCheering: isCheering
            )
        }
        .environment(\.avatarSkin, skin)
        .environment(\.heroFeatures, features)
        .environment(\.heroEquipment, equipment)
        .scaleEffect(size / HeroFigure.designSize.height)
        .frame(width: size * HeroFigure.designSize.width / HeroFigure.designSize.height, height: size)
        .scaleEffect(hasAppeared || isStill ? 1 : 0.6)
        .opacity(hasAppeared || isStill ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: cheer)
        .onChange(of: cheerTrigger) { old, new in if new > old { cheer() } }
        .sensoryFeedback(.impact, trigger: isCheering) { _, cheering in cheering && isHapticsEnabled }
        .onAppear {
            // With Reduce Motion it is simply there, without growing in.
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6)) { hasAppeared = true }
        }
        .accessibilityAddTraits(.isImage)
    }

    public static let aspectRatio = HeroFigure.designSize.width / HeroFigure.designSize.height

    /// Space between the bottom of the avatar's frame and the ground it stands on, for an avatar of height `size`.
    public static func groundInset(forSize size: CGFloat) -> CGFloat {
        size * 11 / HeroFigure.designSize.height
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

// MARK: - Palette per style

extension HeroAvatar.Style {
    /// The colour the rest of the UI uses for this hero (selection, highlights).
    public var tint: Color {
        switch self {
        case .hero: DSColor.heroTeal
        case .cool: DSColor.heroPurple
        case .strong: DSColor.heroOrange
        case .smart: DSColor.heroGreen
        case .chef: DSColor.heroGold
        case .fixer: DSColor.heroBlue
        }
    }

    /// Main garment: top and bottom of its gradient.
    var fabric: LinearGradient {
        switch self {
        case .hero: heroGradient(DSColor.heroTeal, DSColor.heroTealShade)
        case .cool: heroGradient(DSColor.heroPurple, DSColor.heroPurpleShade)
        case .strong, .fixer: heroGradient(DSColor.heroOrange, DSColor.heroCapeShade)
        case .smart: heroGradient(DSColor.heroGreen, DSColor.heroGreenShade)
        case .chef: heroGradient(DSColor.heroChef, DSColor.heroChefShade)
        }
    }

    func sleeve(_ skin: AvatarSkin) -> LinearGradient {
        switch self {
        case .strong: skin.gradient
        case .smart: heroGradient(DSColor.heroChef, DSColor.heroChefShade)
        default: fabric
        }
    }

    /// Glove, wristband, watch or cuff at the wrist.
    var cuff: Color {
        switch self {
        case .hero: DSColor.heroGold
        case .cool: DSColor.heroPurpleShade
        case .strong: DSColor.heroInk
        case .smart: DSColor.heroSteel
        case .chef: DSColor.heroChefShade
        case .fixer: DSColor.heroLeather
        }
    }

    var trousers: Color {
        switch self {
        case .hero: DSColor.heroTealShade
        case .fixer: DSColor.heroNavyShade
        default: DSColor.heroCloth
        }
    }

    var shoes: Color {
        switch self {
        case .hero: DSColor.heroGold
        case .cool: DSColor.heroHighlight
        default: DSColor.heroLeather
        }
    }

    /// Strong Dad is broader than the others.
    var armWidth: CGFloat { self == .strong ? 14 : 11 }
    var shoulderOffset: CGFloat { self == .strong ? 28 : 25 }
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
    /// 0...1, repeating: Strong Dad's dumbbell lift.
    var pump: Double = 0

    static let rest = HeroPose()

    init() {}

    init(time: TimeInterval) {
        bob = sin(time * 2.2) * 2.5
        breath = 1 + sin(time * 2.2) * 0.02
        eyeScale = time.truncatingRemainder(dividingBy: 3.6) < 0.14 ? 0.1 : 1
        look = sin(time * 0.7) * 1.2
        sway = sin(time * 1.6) * 4
        glow = 0.5 + 0.5 * sin(time * 3)
        pump = 0.5 + 0.5 * sin(time * 2.4)
    }
}

/// The whole character on a fixed design canvas. `HeroAvatar` scales it to the requested size.
/// Parts are positioned from the canvas centre and layered back to front.
struct HeroFigure: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let designSize = CGSize(width: 110, height: 160)

    let style: HeroAvatar.Style
    let pose: HeroPose
    let isCheering: Bool
    @Environment(\.heroEquipment) private var equipment
    @Environment(\.heroFeatures) private var features

    /// Super Dad hovers above the ground instead of standing on it.
    private var hover: CGFloat { style == .hero ? pose.bob - 6 : 0 }

    private var rightArmAngle: Double {
        switch style {
        case .hero: isCheering ? -150 : -12
        case .strong: -12 - 45 * pose.pump
        default: -12
        }
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(DSColor.heroInk.opacity(0.15))
                .frame(width: isCheering || style == .hero ? 42 : 58, height: 10)
                .offset(y: 69)
            if let item = equipment.item(in: .ground) {
                HeroGroundItem(item: item, glow: pose.glow)
            }
            ZStack {
                HeroBackGear(style: style, sway: pose.sway)
                HeroLegs(style: style)
                HeroTorso(style: style, breath: pose.breath)
                if let item = equipment.item(in: .hip) {
                    HeroHipItem(item: item, glow: pose.glow)
                }
                HeroMedals(count: equipment.medals)
                HeroArm(style: style, isRight: false, angle: isCheering ? 150 : 8 + pose.sway, sway: pose.sway)
                    .offset(x: -style.shoulderOffset, y: 14)
                HeroArm(style: style, isRight: true, angle: rightArmAngle, sway: pose.sway)
                    .offset(x: style.shoulderOffset, y: 14)
                if let item = equipment.item(in: .shoulder) {
                    HeroShoulderItem(item: item, glow: pose.glow)
                }
                HeroHead(pose: pose, isCheering: isCheering, glasses: style.wornGlasses(features.glasses))
                HeroHeadgear(style: style, pose: pose)
            }
            .offset(y: 12 + pose.bob + hover + (isCheering ? -18 : 0))
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
        // With Reduce Motion the cheer shows at once, without the bounce.
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.45), value: isCheering)
    }
}

/// Top-to-bottom shading used to give flat shapes some volume.
func heroGradient(_ top: Color, _ bottom: Color) -> LinearGradient {
    LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
}

#Preview("Heroes") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
        ForEach(HeroAvatar.Style.allCases, id: \.self) { style in
            HeroAvatar(style: style, size: 170)
        }
    }
    .padding()
    .background(DSColor.background)
}

#Preview("Looks") {
    let looks: [HeroFeatures] = [
        .standard,
        .init(hair: .curly, hairColor: .red, beard: .short, glasses: .round),
        .init(hair: .long, hairColor: .blond, beard: .none),
        .init(hair: .shaved, hairColor: .grey, beard: .full, glasses: .round),
        .init(hair: .short, hairColor: .black, beard: .none, glasses: .round),
        .init(hair: .curly, hairColor: .brown, beard: .full)
    ]
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
        ForEach(Array(zip(HeroAvatar.Style.allCases, looks)), id: \.0) { style, look in
            HeroAvatar(style: style, size: 170, skin: .medium, features: look)
        }
    }
    .padding()
    .background(DSColor.background)
}
