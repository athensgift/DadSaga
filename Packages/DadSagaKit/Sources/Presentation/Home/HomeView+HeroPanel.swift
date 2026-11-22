import DesignSystem
import SwiftUI

// MARK: - The hero's panel

extension HomeView {
    /// The hero, his lines and his level, title and skills. Above a fold he stands beside his lines and the panel,
    /// whose column is wide enough for the four skills side by side (ADR-0059 §3); elsewhere they stand under him.
    func heroPanel(_ content: HomeContent) -> some View {
        let stageAndTitle = isHeroBesideTitle
            ? AnyLayout(HStackLayout(spacing: HomeArrangement.besideSpacing))
            : AnyLayout(VStackLayout(spacing: DSSpacing.m))
        return VStack(spacing: HomeArrangement.headerSpacing) {
            if arrangement.hasPanes {
                paneHeader(content)
            }
            stageAndTitle {
                heroStage(content)
                VStack(spacing: DSSpacing.m) {
                    VStack(spacing: DSSpacing.xs) {
                        // Text in the primary colour: several hero colours are below 3:1 as text (ADR-0033).
                        Text(content.companionLine)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        if let tagline = content.heroTagline {
                            Text(tagline)
                                .font(DSFont.subheadline)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    StandingPanel(title: content.dadTitle, skills: content.skills, bounces: viewModel.skillBounces) {
                        skillsRowWidth = $0
                    }
                }
                .frame(width: besideColumnWidth)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { underHeroHeight = $0 }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Beside the hero, his column takes half the pane, or more when the four skills need it side by side: the hero
    /// yields the width. `nil` when the column stands under him.
    private var besideColumnWidth: CGFloat? {
        guard isHeroBesideTitle else { return nil }
        let content = width - HomeArrangement.panePadding * 2 - HomeArrangement.besideSpacing
        return min(content - HomeArrangement.smallestStageWidth, max(content / 2, skillsRowWidth + StandingPanel.padding * 2))
    }

    /// The hero's height: what his pane leaves him (ADR-0056 §3, ADR-0059 §3).
    var maxHeroSize: CGFloat {
        arrangement.maxHeroSize(
            headerHeight: paneHeaderHeight,
            besideTitle: isHeroBesideTitle,
            under: isHeroBesideTitle ? 0 : underHeroHeight,
            paneHeight: heroPaneHeight
        )
    }
}
