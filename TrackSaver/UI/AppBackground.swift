import SwiftUI

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.06),
                    Color(red: 0.06, green: 0.09, blue: 0.10),
                    Color(red: 0.09, green: 0.13, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    StyleKit.accent.opacity(0.52),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    StyleKit.accentWarm.opacity(0.28),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 16,
                endRadius: 360
            )

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 140, y: -240)

            Circle()
                .fill(StyleKit.accentSoft.opacity(0.55))
                .frame(width: 260, height: 260)
                .blur(radius: 85)
                .offset(x: -140, y: 250)
        }
        .ignoresSafeArea()
    }
}

enum GlassCardStyle {
    case hero
    case standard
    case compact
}

private extension GlassCardStyle {
    var cornerRadius: CGFloat {
        switch self {
        case .hero: return StyleKit.Radius.hero
        case .standard: return StyleKit.Radius.card
        case .compact: return StyleKit.Radius.compact
        }
    }

    var contentPadding: CGFloat {
        switch self {
        case .hero: return 20
        case .standard: return 16
        case .compact: return 13
        }
    }

    var fill: Color {
        switch self {
        case .hero: return StyleKit.surfaceStrong
        case .standard: return StyleKit.surface
        case .compact: return StyleKit.surfaceSoft
        }
    }

    var stroke: Color {
        switch self {
        case .hero: return StyleKit.strokeStrong
        case .standard: return StyleKit.stroke
        case .compact: return StyleKit.strokeSoft
        }
    }

    var tint: Color {
        switch self {
        case .hero: return StyleKit.accent.opacity(0.22)
        case .standard: return StyleKit.accent.opacity(0.13)
        case .compact: return StyleKit.accent.opacity(0.08)
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .hero: return 0.22
        case .standard: return 0.16
        case .compact: return 0.10
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .hero: return 20
        case .standard: return 14
        case .compact: return 9
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .hero: return 8
        case .standard: return 5
        case .compact: return 3
        }
    }
}

struct GlassCard<Content: View>: View {
    var style: GlassCardStyle = .standard
    let content: Content

    init(style: GlassCardStyle = .standard, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(style.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(style.fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                            .stroke(style.stroke, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                            .opacity(0.55)
                    }
                    .glassEffect(
                        StyleKit.glass(tint: style.tint),
                        in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    )
                    .shadow(color: .black.opacity(style.shadowOpacity), radius: style.shadowRadius, x: 0, y: style.shadowY)
            )
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(StyleKit.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(StyleKit.surfaceSoft)
                    .overlay(Capsule().stroke(StyleKit.strokeSoft, lineWidth: 1))
                    .glassEffect(
                        StyleKit.glass(tint: StyleKit.accent.opacity(0.08)),
                        in: Capsule()
                    )
            )
    }
}
