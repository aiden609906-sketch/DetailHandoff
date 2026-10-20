import SwiftUI

struct PrimaryCreationAction: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                        actionIcon
                        actionText
                    }
                } else {
                    HStack(spacing: AppTheme.spacing12) {
                        actionIcon
                        actionText
                        Spacer(minLength: AppTheme.spacing8)
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing12)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.gradient)
            )
            .shadow(color: Color.accentColor.opacity(0.22), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var actionIcon: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .frame(width: 34, height: 34)
            .background(.white.opacity(0.18), in: Circle())
            .accessibilityHidden(true)
    }

    private var actionText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
