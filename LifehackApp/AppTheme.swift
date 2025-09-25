import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacing: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radius

    static let corner: CGFloat = 16
    static let cornerSmall: CGFloat = 12
    static let cornerLarge: CGFloat = 32

    // MARK: - Padding

    static let cardPadding: CGFloat = 16

    // MARK: - Colors (expects matching asset names; fallbacks included)

    static var background: Color { Color("Background", bundle: .main).opacity(1) }
    static var cardBackground: Color { Color.white.opacity(0.08) }
    static var accent: Color { Color("AccentColor", bundle: .main) }
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shadows

    static var cardShadow: ShadowStyle { .init(color: .black.opacity(0.35), radius: 22, y: 10) }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat = 0
        let y: CGFloat
    }

    // MARK: - Animations

    static let easePop = Animation.spring(response: 0.5, dampingFraction: 0.75)
    static let easeFast = Animation.easeOut(duration: 0.25)

    // MARK: - Glass material style (used by GlassCard or inline)

    @ViewBuilder
    static func glassBackground(cornerRadius: CGFloat = corner) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.65))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Liquid Glass modifier (applies to any container like buttons, menus, cards)

    struct LiquidGlass: ViewModifier {
        var cornerRadius: CGFloat = AppTheme.corner
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                )
        }
    }

    static func liquidGlass(cornerRadius: CGFloat = corner) -> some ViewModifier { LiquidGlass(cornerRadius: corner) }

    // MARK: - Button Styles

    struct LiquidGlassButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerSmall, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerSmall, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(AppTheme.easeFast, value: configuration.isPressed)
        }
    }

    // MARK: - Card style wrapper

    @ViewBuilder
    static func card<Content: View>(
        cornerRadius: CGFloat = corner,
        padding: CGFloat = cardPadding,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .background(glassBackground(cornerRadius: cornerRadius))
            .shadow(color: cardShadow.color, radius: cardShadow.radius, x: cardShadow.x, y: cardShadow.y)
    }

    // MARK: - Global UIAppearance configuration (called from App init)

    static func configureGlobal() {
        #if canImport(UIKit)
        // Navigation Bar glass appearance
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        nav.titleTextAttributes = [.foregroundColor: UIColor.label]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        // Tab Bar glass appearance
        let tb = UITabBarAppearance()
        tb.configureWithTransparentBackground()
        tb.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = tb
        UITabBar.appearance().scrollEdgeAppearance = tb
        #endif
    }

    // MARK: - Environment tokens (lightweight; can be overridden later)

    struct Tokens {
        let corner = AppTheme.corner
        let padding = AppTheme.cardPadding
        let spacing = AppTheme.spacing
        let accent = AppTheme.accent
    }

    struct ThemeTokensKey: EnvironmentKey {
        static let defaultValue: Tokens = .init()
    }

    static func tokens() -> Tokens { Tokens() }
}

extension EnvironmentValues {
    var themeTokens: AppTheme.Tokens {
        get { self[AppTheme.ThemeTokensKey.self] }
        set { self[AppTheme.ThemeTokensKey.self] = newValue }
    }
}

extension View {
    func appThemeTokens(_ tokens: AppTheme.Tokens) -> some View {
        environment(\.themeTokens, tokens)
    }

    // Apply liquid glass style quickly to any view container
    func liquidGlass(cornerRadius: CGFloat = AppTheme.corner) -> some View {
        modifier(AppTheme.LiquidGlass(cornerRadius: cornerRadius))
    }
}
