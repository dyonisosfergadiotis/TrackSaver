import SwiftUI

enum AppBackgroundStyle {
    case standard
    case menuBarPopover
}

struct AppBackground: View {
    var style: AppBackgroundStyle = .standard
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    StyleKit.accent.opacity(primaryGlowOpacity),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 18,
                endRadius: primaryGlowRadius
            )

            RadialGradient(
                colors: [
                    StyleKit.accentWarm.opacity(secondaryGlowOpacity),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 16,
                endRadius: secondaryGlowRadius
            )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            StyleKit.glassSpecular.opacity(topHighlightOpacity),
                            StyleKit.glassReflection.opacity(topReflectionOpacity),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: topEllipseSize.width, height: topEllipseSize.height)
                .blur(radius: topEllipseBlur)
                .rotationEffect(.degrees(topEllipseRotation))
                .offset(x: topEllipseOffset.width, y: topEllipseOffset.height)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            StyleKit.glassReflection.opacity(capsuleOpacity),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: accentCapsuleSize.width, height: accentCapsuleSize.height)
                .blur(radius: accentCapsuleBlur)
                .rotationEffect(.degrees(accentCapsuleRotation))
                .offset(x: accentCapsuleOffset.width, y: accentCapsuleOffset.height)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            StyleKit.accentSoft.opacity(lowerAccentOpacity),
                            StyleKit.glassGlow.opacity(lowerGlowOpacity),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: lowerEllipseSize.width, height: lowerEllipseSize.height)
                .blur(radius: lowerEllipseBlur)
                .offset(x: lowerEllipseOffset.width, y: lowerEllipseOffset.height)

            Circle()
                .fill(Color.white.opacity(floatingLightOpacity))
                .frame(width: floatingLightSize, height: floatingLightSize)
                .blur(radius: floatingLightBlur)
                .offset(x: floatingLightOffset.width, y: floatingLightOffset.height)
        }
        .ignoresSafeArea()
    }

    private var backgroundColors: [Color] {
        switch (style, colorScheme) {
        case (.menuBarPopover, .dark):
            return [
                Color(red: 0.05, green: 0.08, blue: 0.09),
                Color(red: 0.07, green: 0.11, blue: 0.12),
                Color(red: 0.09, green: 0.13, blue: 0.13)
            ]
        case (.menuBarPopover, _):
            return [
                Color(red: 0.94, green: 0.985, blue: 0.975),
                Color(red: 0.84, green: 0.96, blue: 0.94),
                Color(red: 0.74, green: 0.935, blue: 0.89)
            ]
        case (_, .dark):
            return [
                Color(red: 0.03, green: 0.06, blue: 0.07),
                Color(red: 0.05, green: 0.10, blue: 0.11),
                Color(red: 0.09, green: 0.14, blue: 0.13)
            ]
        default:
            return [
                Color(red: 0.92, green: 0.985, blue: 0.965),
                Color(red: 0.80, green: 0.96, blue: 0.92),
                Color(red: 0.66, green: 0.93, blue: 0.84)
            ]
        }
    }

    private var primaryGlowOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.54 : 0.36
        case .menuBarPopover:
            return colorScheme == .dark ? 0.26 : 0.22
        }
    }

    private var secondaryGlowOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.30 : 0.26
        case .menuBarPopover:
            return colorScheme == .dark ? 0.16 : 0.16
        }
    }

    private var primaryGlowRadius: CGFloat {
        style == .menuBarPopover ? 250 : 360
    }

    private var secondaryGlowRadius: CGFloat {
        style == .menuBarPopover ? 300 : 400
    }

    private var topHighlightOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.18 : 0.70
        case .menuBarPopover:
            return colorScheme == .dark ? 0.10 : 0.42
        }
    }

    private var topReflectionOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.08 : 0.22
        case .menuBarPopover:
            return colorScheme == .dark ? 0.05 : 0.16
        }
    }

    private var topEllipseSize: CGSize {
        style == .menuBarPopover
            ? CGSize(width: 300, height: 420)
            : CGSize(width: 360, height: 560)
    }

    private var topEllipseBlur: CGFloat {
        style == .menuBarPopover ? 24 : 18
    }

    private var topEllipseRotation: Double {
        style == .menuBarPopover ? -18 : -24
    }

    private var topEllipseOffset: CGSize {
        style == .menuBarPopover
            ? CGSize(width: 124, height: -192)
            : CGSize(width: 154, height: -220)
    }

    private var capsuleOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.10 : 0.24
        case .menuBarPopover:
            return colorScheme == .dark ? 0.06 : 0.14
        }
    }

    private var accentCapsuleSize: CGSize {
        style == .menuBarPopover
            ? CGSize(width: 280, height: 112)
            : CGSize(width: 420, height: 150)
    }

    private var accentCapsuleBlur: CGFloat {
        style == .menuBarPopover ? 20 : 26
    }

    private var accentCapsuleRotation: Double {
        style == .menuBarPopover ? 12 : 18
    }

    private var accentCapsuleOffset: CGSize {
        style == .menuBarPopover
            ? CGSize(width: -84, height: -86)
            : CGSize(width: -90, height: -112)
    }

    private var lowerAccentOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.58 : 0.26
        case .menuBarPopover:
            return colorScheme == .dark ? 0.20 : 0.12
        }
    }

    private var lowerGlowOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.20 : 0.14
        case .menuBarPopover:
            return colorScheme == .dark ? 0.10 : 0.08
        }
    }

    private var lowerEllipseSize: CGSize {
        style == .menuBarPopover
            ? CGSize(width: 240, height: 240)
            : CGSize(width: 320, height: 320)
    }

    private var lowerEllipseBlur: CGFloat {
        style == .menuBarPopover ? 72 : 96
    }

    private var lowerEllipseOffset: CGSize {
        style == .menuBarPopover
            ? CGSize(width: -116, height: 212)
            : CGSize(width: -148, height: 252)
    }

    private var floatingLightOpacity: Double {
        switch style {
        case .standard:
            return colorScheme == .dark ? 0.08 : 0.40
        case .menuBarPopover:
            return colorScheme == .dark ? 0.04 : 0.22
        }
    }

    private var floatingLightSize: CGFloat {
        style == .menuBarPopover ? 220 : 280
    }

    private var floatingLightBlur: CGFloat {
        style == .menuBarPopover ? 72 : 94
    }

    private var floatingLightOffset: CGSize {
        style == .menuBarPopover
            ? CGSize(width: 100, height: 220)
            : CGSize(width: 116, height: 264)
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

    var material: Material {
        switch self {
        case .hero: return .regularMaterial
        case .standard: return .thinMaterial
        case .compact: return .ultraThinMaterial
        }
    }

    var glowColor: Color {
        switch self {
        case .hero: return StyleKit.glassGlowWarm
        case .standard: return StyleKit.glassGlow
        case .compact: return StyleKit.glassGlow
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .hero: return 0.26
        case .standard: return 0.18
        case .compact: return 0.12
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .hero: return 18
        case .standard: return 12
        case .compact: return 7
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .hero: return 8
        case .standard: return 5
        case .compact: return 3
        }
    }

    var glass: Glass {
        switch self {
        case .hero: return .regular
        case .standard: return .regular
        case .compact: return .clear
        }
    }

    var usesDynamicGlassEffect: Bool {
        switch self {
        case .compact:
            return false
        case .hero, .standard:
            return true
        }
    }
}

struct LiquidGlassPlate: View {
    let cornerRadius: CGFloat
    var tint: Color
    var edgeTint: Color
    var glowColor: Color = StyleKit.glassGlow
    var material: Material = .thinMaterial
    var shadowOpacity: Double = 0.18
    var shadowRadius: CGFloat = 12
    var shadowY: CGFloat = 4

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape.fill(material)

            shape.fill(
                LinearGradient(
                    colors: [
                        tint.opacity(colorScheme == .dark ? 1.0 : 0.96),
                        tint.opacity(colorScheme == .dark ? 0.80 : 0.68)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            shape.fill(
                LinearGradient(
                    colors: [
                        StyleKit.glassHighlight.opacity(colorScheme == .dark ? 0.14 : 0.34),
                        Color.clear,
                        StyleKit.glassReflection.opacity(colorScheme == .dark ? 0.08 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            StyleKit.glassSpecular.opacity(colorScheme == .dark ? 0.26 : 0.80),
                            StyleKit.glassReflection.opacity(colorScheme == .dark ? 0.08 : 0.20),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: cornerRadius * 4.4, height: cornerRadius * 3.2)
                .blur(radius: 12)
                .offset(x: -cornerRadius * 0.9, y: -cornerRadius * 1.05)
                .blendMode(.screen)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            glowColor.opacity(colorScheme == .dark ? 0.28 : 0.22),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: cornerRadius * 4.8, height: cornerRadius * 2.8)
                .blur(radius: 24)
                .rotationEffect(.degrees(-14))
                .offset(x: cornerRadius * 0.9, y: cornerRadius * 0.95)
                .blendMode(.screen)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: cornerRadius * 4.2, height: cornerRadius * 1.8)
                .blur(radius: 18)
                .offset(x: -cornerRadius * 0.35, y: cornerRadius * 1.40)
                .blendMode(.multiply)

            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        StyleKit.glassSpecular.opacity(colorScheme == .dark ? 0.36 : 0.86),
                        edgeTint.opacity(0.94),
                        StyleKit.glassReflection.opacity(colorScheme == .dark ? 0.08 : 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.05
            )

            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        StyleKit.glassSpecular.opacity(colorScheme == .dark ? 0.18 : 0.48),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 0.8
            )
        }
        .clipShape(shape)
        .compositingGroup()
        .shadow(color: StyleKit.shadow.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
        .shadow(color: glowColor.opacity(shadowOpacity * (colorScheme == .dark ? 0.36 : 0.18)), radius: shadowRadius * 1.1, x: 0, y: shadowY * 0.6)
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
            .background {
                GlassCardBackground(style: style)
            }
    }
}

struct GlassCardBackground: View {
    let style: GlassCardStyle

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)

        Group {
            if style.usesDynamicGlassEffect {
                Color.white.opacity(0.001)
                    .glassEffect(style.glass, in: shape)
            } else {
                shape.fill(style.material)
            }
        }
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18),
                            style.fill.opacity(colorScheme == .dark ? 0.14 : 0.26),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.24 : 0.46),
                            style.stroke.opacity(0.88),
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: StyleKit.shadow.opacity(style.shadowOpacity * (colorScheme == .dark ? 0.72 : 0.52)),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowY
            )
            .shadow(
                color: style.glowColor.opacity(colorScheme == .dark ? 0.12 : 0.08),
                radius: style.shadowRadius * 1.05,
                x: 0,
                y: style.shadowY * 0.55
            )
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(StyleKit.textMuted)
    }
}
