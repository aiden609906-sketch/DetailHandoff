import SwiftUI
import UIKit

enum AppTheme {
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
}

struct ReportCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.spacing16)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            }
    }
}

extension View {
    func reportCard() -> some View {
        modifier(ReportCardModifier())
    }
}
