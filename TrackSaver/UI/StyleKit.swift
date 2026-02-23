import SwiftUI

enum StyleKit {
    static let accent = Color(red: 0.30, green: 0.88, blue: 0.59)
    static let accentWarm = Color(red: 0.90, green: 0.71, blue: 0.47)
    static let accentSoft = Color(red: 0.15, green: 0.34, blue: 0.23)

    static let surfaceStrong = Color.white.opacity(0.16)
    static let surface = Color.white.opacity(0.11)
    static let surfaceSoft = Color.white.opacity(0.07)

    static let strokeStrong = Color.white.opacity(0.26)
    static let stroke = Color.white.opacity(0.17)
    static let strokeSoft = Color.white.opacity(0.10)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.82)
    static let textMuted = Color.white.opacity(0.60)

    enum Radius {
        static let chip: CGFloat = 12
        static let compact: CGFloat = 16
        static let card: CGFloat = 22
        static let hero: CGFloat = 30
        static let accessory: CGFloat = 26
    }

    static func glass(tint: Color? = nil, interactive: Bool = false) -> Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }

    static func historyStatusColor(_ status: String) -> Color {
        status == "success" ? accent : accentWarm
    }
}

struct IconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(StyleKit.textPrimary)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: StyleKit.Radius.chip, style: .continuous)
                    .fill(StyleKit.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleKit.Radius.chip, style: .continuous)
                            .stroke(StyleKit.stroke, lineWidth: 1)
                    )
                    .glassEffect(
                        StyleKit.glass(tint: StyleKit.accent.opacity(0.22), interactive: true),
                        in: RoundedRectangle(cornerRadius: StyleKit.Radius.chip, style: .continuous)
                    )
            )
    }
}
