import DesignSystem
import SwiftUI

/// "I'm raising them with a partner", with the line under it (ADR-0051 §4). On by default; nothing asks why.
struct PartnerRow: View {
    @Binding var hasPartner: Bool
    let labels: PartnerRowLabels

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Toggle(labels.title, isOn: $hasPartner)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
            Text(labels.line)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DSSpacing.m)
        .padding(.vertical, DSSpacing.s)
        .frame(minHeight: 50)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}
