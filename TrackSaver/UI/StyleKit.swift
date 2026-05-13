import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
#endif

enum StyleKit {
    private static func dynamicColor(light: PlatformColor, dark: PlatformColor) -> Color {
        #if canImport(UIKit)
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
        #elseif canImport(AppKit)
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        )
        #endif
    }

    static let accent = Color(red: 0.30, green: 0.88, blue: 0.59)
    static let accentWarm = Color(red: 0.90, green: 0.71, blue: 0.47)
    static let accentSoft = Color(red: 0.15, green: 0.34, blue: 0.23)

    static let surfaceStrong = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.28),
        dark: PlatformColor.white.withAlphaComponent(0.12)
    )
    static let surface = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.20),
        dark: PlatformColor.white.withAlphaComponent(0.09)
    )
    static let surfaceSoft = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.14),
        dark: PlatformColor.white.withAlphaComponent(0.07)
    )

    static let strokeStrong = dynamicColor(
        light: PlatformColor.black.withAlphaComponent(0.10),
        dark: PlatformColor.white.withAlphaComponent(0.16)
    )
    static let stroke = dynamicColor(
        light: PlatformColor.black.withAlphaComponent(0.08),
        dark: PlatformColor.white.withAlphaComponent(0.12)
    )
    static let strokeSoft = dynamicColor(
        light: PlatformColor.black.withAlphaComponent(0.05),
        dark: PlatformColor.white.withAlphaComponent(0.08)
    )

    static let textPrimary = dynamicColor(
        light: PlatformColor(red: 0.09, green: 0.13, blue: 0.14, alpha: 1.0),
        dark: PlatformColor.white
    )
    static let textSecondary = dynamicColor(
        light: PlatformColor(red: 0.09, green: 0.13, blue: 0.14, alpha: 0.74),
        dark: PlatformColor.white.withAlphaComponent(0.80)
    )
    static let textMuted = dynamicColor(
        light: PlatformColor(red: 0.09, green: 0.13, blue: 0.14, alpha: 0.56),
        dark: PlatformColor.white.withAlphaComponent(0.58)
    )

    static let cardSheen = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.36),
        dark: PlatformColor.white.withAlphaComponent(0.10)
    )
    static let glassHighlight = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.80),
        dark: PlatformColor.white.withAlphaComponent(0.20)
    )
    static let glassReflection = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.30),
        dark: PlatformColor.white.withAlphaComponent(0.10)
    )
    static let glassSpecular = dynamicColor(
        light: PlatformColor.white.withAlphaComponent(0.96),
        dark: PlatformColor.white.withAlphaComponent(0.34)
    )
    static let glassGlow = dynamicColor(
        light: PlatformColor(red: 0.50, green: 0.93, blue: 0.75, alpha: 0.32),
        dark: PlatformColor(red: 0.36, green: 0.80, blue: 0.66, alpha: 0.24)
    )
    static let glassGlowWarm = dynamicColor(
        light: PlatformColor(red: 0.98, green: 0.88, blue: 0.68, alpha: 0.28),
        dark: PlatformColor(red: 0.94, green: 0.78, blue: 0.58, alpha: 0.20)
    )
    static let shadow = dynamicColor(
        light: PlatformColor.black.withAlphaComponent(0.16),
        dark: PlatformColor.black.withAlphaComponent(0.40)
    )

    enum Radius {
        static let chip: CGFloat = 12
        static let compact: CGFloat = 16
        static let card: CGFloat = 22
        static let hero: CGFloat = 30
        static let accessory: CGFloat = 26
    }

    static func historyStatusColor(_ status: String) -> Color {
        status == "success" ? accent : accentWarm
    }
}

enum TrackSaverPresentationStyle {
    case standard
    case menuBarPopover
}

struct IconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(StyleKit.textPrimary)
            .frame(width: 40, height: 40)
            .background(
                LiquidGlassPlate(
                    cornerRadius: StyleKit.Radius.chip,
                    tint: StyleKit.surfaceSoft,
                    edgeTint: StyleKit.stroke,
                    glowColor: StyleKit.glassGlow,
                    material: .thinMaterial,
                    shadowOpacity: 0.18,
                    shadowRadius: 8,
                    shadowY: 3
                )
            )
    }
}
