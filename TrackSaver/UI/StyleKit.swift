import SwiftUI

enum StyleKit {
    static let accent = Color(red: 0.12, green: 0.82, blue: 0.47)
    static let accentSoft = Color(red: 0.16, green: 0.32, blue: 0.20)
    static let iconSurface = Color.white.opacity(0.12)
    static let iconStroke = Color.white.opacity(0.18)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.55)
}

struct IconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(StyleKit.accent)
            .padding(10)
            .background(
                Circle()
                    .fill(StyleKit.iconSurface)
                    .overlay(Circle().stroke(StyleKit.iconStroke, lineWidth: 1))
            )
    }
}

struct ActionCapsule: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(StyleKit.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(StyleKit.iconSurface)
                    .overlay(Capsule().stroke(StyleKit.iconStroke, lineWidth: 1))
            )
    }
}
