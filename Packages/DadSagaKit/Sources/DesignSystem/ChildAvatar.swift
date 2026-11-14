import SwiftUI

/// A child companion, drawn in code like `HeroAvatar`. Four age stages, each smaller and rounder the younger the
/// child; gender changes hair and accessories, not clothing colours. Idles, blinks and cheers. Honours Reduce Motion.
///
/// Every stage is drawn on the same canvas with its feet on the same ground line, so children of different ages
/// standing side by side keep their real height difference.
public struct ChildAvatar: View {
    public enum Stage: CaseIterable, Sendable {
        /// 0–11 months: sits, has a dummy.
        case baby
        /// 1–2 years: stands, holds a teddy.
        case toddler
        /// 3–5 years.
        case preschooler
        /// 6 years and up: has a school backpack.
        case kid
    }

    public enum Gender: CaseIterable, Sendable {
        case boy, girl
    }

    private let stage: Stage
    private let gender: Gender
    private let skin: AvatarSkin
    private let size: CGFloat
    private let cheerTrigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCheering = false
    @State private var hasAppeared = false

    /// - Parameters:
    ///   - size: the canvas height in points. A `kid` fills most of it; a `baby` about half.
    ///   - cheerTrigger: change this value to make the child cheer.
    public init(stage: Stage, gender: Gender, skin: AvatarSkin, size: CGFloat = 120, cheerTrigger: Int = 0) {
        self.stage = stage
        self.gender = gender
        self.skin = skin
        self.size = size
        self.cheerTrigger = cheerTrigger
    }

    public static let aspectRatio = ChildFigure.designSize.width / ChildFigure.designSize.height

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            ChildFigure(
                stage: stage,
                gender: gender,
                pose: reduceMotion ? .rest : HeroPose(time: context.date.timeIntervalSinceReferenceDate + 0.7),
                isCheering: isCheering
            )
        }
        .environment(\.avatarSkin, skin)
        .scaleEffect(size / ChildFigure.designSize.height)
        .frame(width: size * Self.aspectRatio, height: size)
        .scaleEffect(hasAppeared ? 1 : 0.6, anchor: .bottom)
        .opacity(hasAppeared ? 1 : 0)
        .onChange(of: cheerTrigger) { cheer() }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { hasAppeared = true }
        }
        .accessibilityAddTraits(.isImage)
    }

    /// Space between the bottom of the avatar's frame and the ground it stands on, for an avatar of height `size`.
    public static func groundInset(forSize size: CGFloat) -> CGFloat {
        size * 6 / ChildFigure.designSize.height
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

/// Body proportions per stage, in the stage's own units (before `scale`). Younger: bigger head, shorter legs.
private struct ChildProportions {
    let scale: CGFloat
    let headRadius: CGFloat
    let torso: CGSize
    let legHeight: CGFloat
    let clothes: Color
    let clothesShade: Color

    init(_ stage: ChildAvatar.Stage) {
        switch stage {
        case .baby:
            self.init(scale: 0.6, headRadius: 22, torso: CGSize(width: 32, height: 26), legHeight: 0,
                      clothes: Color(light: 0xF4C95D, dark: 0xF6D47A), clothesShade: Color(light: 0xD9A82E, dark: 0xD9A82E))
        case .toddler:
            self.init(scale: 0.7, headRadius: 21, torso: CGSize(width: 30, height: 25), legHeight: 15,
                      clothes: Color(light: 0x5B8DEF, dark: 0x7FA6F5), clothesShade: Color(light: 0x3B66C4, dark: 0x5B82D6))
        case .preschooler:
            self.init(scale: 0.84, headRadius: 20, torso: CGSize(width: 30, height: 28), legHeight: 21,
                      clothes: Color(light: 0x3FA56B, dark: 0x56C083), clothesShade: Color(light: 0x2C7A4C, dark: 0x3F9663))
        case .kid:
            self.init(scale: 0.97, headRadius: 19, torso: CGSize(width: 31, height: 32), legHeight: 27,
                      clothes: Color(light: 0xF08A4B, dark: 0xF5A06A), clothesShade: Color(light: 0xC9672C, dark: 0xD9804A))
        }
    }

    private init(scale: CGFloat, headRadius: CGFloat, torso: CGSize, legHeight: CGFloat, clothes: Color, clothesShade: Color) {
        self.scale = scale
        self.headRadius = headRadius
        self.torso = torso
        self.legHeight = legHeight
        self.clothes = clothes
        self.clothesShade = clothesShade
    }
}

/// The whole child on a fixed canvas, drawn upwards from the ground line.
struct ChildFigure: View {
    static let designSize = CGSize(width: 80, height: 120)
    /// Distance of the ground line below the canvas centre.
    private static let ground: CGFloat = 54

    let stage: ChildAvatar.Stage
    let gender: ChildAvatar.Gender
    let pose: HeroPose
    let isCheering: Bool
    @Environment(\.avatarSkin) private var skin

    private var proportions: ChildProportions { ChildProportions(stage) }
    private var torsoBottom: CGFloat { stage == .baby ? -8 : -proportions.legHeight }
    private var torsoCentre: CGFloat { torsoBottom - proportions.torso.height / 2 }
    private var headCentre: CGFloat { torsoBottom - proportions.torso.height - proportions.headRadius + 5 }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(DSColor.heroInk.opacity(0.13))
                .frame(width: isCheering ? 26 : 40, height: 7)
                .offset(y: Self.ground)
            ZStack {
                if stage == .kid { backpack }
                ChildHair(stage: stage, gender: gender, layer: .back, headRadius: proportions.headRadius, sway: pose.sway)
                    .offset(y: headCentre)
                legs
                torso
                arms
                head
                ChildHair(stage: stage, gender: gender, layer: .front, headRadius: proportions.headRadius, sway: pose.sway)
                    .offset(y: headCentre)
                face
                if stage == .toddler { teddy }
            }
            // A zero-height frame puts the ground line at the centre, so scaling keeps the feet on the ground.
            .frame(width: Self.designSize.width, height: 0)
            .scaleEffect(proportions.scale)
            .offset(y: Self.ground + (stage == .baby ? 0 : pose.bob * 0.6) + (isCheering ? -12 : 0))
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: isCheering)
    }

    // MARK: Body

    @ViewBuilder private var legs: some View {
        if stage == .baby {
            // Sitting: short legs pointing forward and out.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(heroGradient(proportions.clothes, proportions.clothesShade))
                    .frame(width: 22, height: 12)
                    .rotationEffect(.degrees(side * 18))
                    .offset(x: side * 12, y: -5)
                Circle()
                    .fill(skin.base)
                    .frame(width: 10, height: 10)
                    .offset(x: side * 23, y: -2)
            }
        } else {
            ForEach([-1.0, 1.0], id: \.self) { side in
                RoundedRectangle(cornerRadius: 4)
                    .fill(stage == .toddler ? skin.base : DSColor.heroCloth)
                    .frame(width: 10, height: proportions.legHeight + 2)
                    .offset(x: side * 7, y: -proportions.legHeight / 2)
                Capsule()
                    .fill(stage == .kid ? DSColor.heroHighlight : DSColor.heroLeather)
                    .overlay { Capsule().strokeBorder(DSColor.heroInk.opacity(0.25), lineWidth: 1) }
                    .frame(width: 14, height: 7)
                    .offset(x: side * 8.5, y: -2)
            }
        }
    }

    private var torso: some View {
        ZStack {
            RoundedRectangle(cornerRadius: stage == .baby ? 14 : 11)
                .fill(heroGradient(proportions.clothes, proportions.clothesShade))
                .frame(width: proportions.torso.width, height: proportions.torso.height)
            switch stage {
            case .baby:
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DSColor.heroHighlight.opacity(0.85))
            case .toddler:
                // Dungarees bib and straps.
                RoundedRectangle(cornerRadius: 3)
                    .fill(proportions.clothesShade)
                    .frame(width: 16, height: 12)
                    .offset(y: 5)
                ForEach([-6.0, 6.0], id: \.self) { side in
                    Circle().fill(DSColor.legendary).frame(width: 3, height: 3).offset(x: side, y: 0)
                }
            case .preschooler:
                Circle()
                    .fill(DSColor.legendary)
                    .frame(width: 9, height: 9)
                    .overlay { Circle().fill(DSColor.heroHighlight).frame(width: 3, height: 3) }
                    .offset(y: 1)
            case .kid:
                ForEach([-9.0, 9.0], id: \.self) { side in
                    Capsule().fill(DSColor.heroKnightShade).frame(width: 4, height: proportions.torso.height - 4).offset(x: side)
                }
            }
        }
        .offset(y: torsoCentre)
    }

    private var arms: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            let angle = isCheering ? side * 150 : side * (10 + pose.sway * 0.6)
            VStack(spacing: -2) {
                Capsule()
                    .fill(heroGradient(proportions.clothesShade, proportions.clothesShade))
                    .overlay { Capsule().strokeBorder(DSColor.heroInk.opacity(0.12), lineWidth: 1) }
                    .frame(width: 8, height: stage == .baby ? 12 : 16)
                Circle().fill(skin.base).frame(width: 8, height: 8)
            }
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(x: side * (proportions.torso.width / 2 + 1), y: torsoCentre - proportions.torso.height / 2 + 11)
        }
    }

    private var head: some View {
        let radius = proportions.headRadius
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle().fill(skin.shade).frame(width: 8, height: 8).offset(x: side * radius)
            }
            Circle().fill(skin.base).frame(width: radius * 2, height: radius * 2)
        }
        .offset(y: headCentre)
    }

    private var face: some View {
        let radius = proportions.headRadius
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    Ellipse().fill(DSColor.heroInk).frame(width: 6, height: 7)
                    Circle().fill(DSColor.heroHighlight).frame(width: 2, height: 2).offset(x: pose.look * 0.5 + 1, y: -1.5)
                }
                .scaleEffect(x: 1, y: pose.eyeScale)
                .offset(x: side * radius * 0.4, y: 1)
                Circle().fill(DSColor.heroBlush.opacity(0.5)).frame(width: 7, height: 5).offset(x: side * radius * 0.62, y: 8)
            }
            if stage == .baby {
                // Dummy.
                ZStack {
                    Ellipse().fill(DSColor.heroTeal).frame(width: 12, height: 7)
                    Circle().fill(DSColor.heroHighlight).frame(width: 4, height: 4)
                }
                .offset(y: 11)
            } else {
                HeroMouth(openness: isCheering ? 1 : 0)
                    .fill(DSColor.heroInk.opacity(0.85))
                    .frame(width: 9, height: 6)
                    .offset(y: 10)
            }
        }
        .offset(y: headCentre)
    }

    // MARK: Accessories

    private var teddy: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle().fill(DSColor.heroWood).frame(width: 6, height: 6).offset(x: side * 5, y: -8)
            }
            Circle().fill(DSColor.heroWood).frame(width: 13, height: 13).offset(y: -3)
            Ellipse().fill(DSColor.heroWood).frame(width: 14, height: 15).offset(y: 8)
            Circle().fill(DSColor.heroInk).frame(width: 2, height: 2).offset(y: -3)
        }
        .rotationEffect(.degrees(-10 + pose.sway))
        .offset(x: proportions.torso.width / 2 + 4, y: torsoCentre + 6)
    }

    private var backpack: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(heroGradient(DSColor.accent, DSColor.heroKnightShade))
            .frame(width: proportions.torso.width + 8, height: proportions.torso.height - 2)
            .offset(y: torsoCentre - 2)
    }
}

#Preview("Children") {
    VStack(spacing: DSSpacing.l) {
        ForEach(ChildAvatar.Gender.allCases, id: \.self) { gender in
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(ChildAvatar.Stage.allCases, id: \.self) { stage in
                    ChildAvatar(stage: stage, gender: gender, skin: gender == .boy ? .medium : .mediumDark, size: 140)
                }
            }
        }
    }
    .padding()
    .background(DSColor.background)
}
