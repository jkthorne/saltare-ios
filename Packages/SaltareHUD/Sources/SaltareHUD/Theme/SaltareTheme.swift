import SwiftUI

// MARK: - Environment keys

private struct SaltareColorsKey: EnvironmentKey {
    static let defaultValue: SaltareColors = .dark
}

private struct SaltareTypographyKey: EnvironmentKey {
    static let defaultValue = SaltareTypography()
}

private struct SaltareSpacingKey: EnvironmentKey {
    static let defaultValue = SaltareSpacing()
}

/// Foundation-only equivalent of Material's `LocalContentColor`. `nil` means
/// "inherit the style's color, falling back to `frost`".
private struct HudContentColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

/// Foundation-only equivalent of Material's `LocalTextStyle` — the ambient HUD
/// text style merged by `HudText`.
private struct HudTextStyleKey: EnvironmentKey {
    static let defaultValue: HudTextStyle? = nil
}

public extension EnvironmentValues {
    var saltareColors: SaltareColors {
        get { self[SaltareColorsKey.self] }
        set { self[SaltareColorsKey.self] = newValue }
    }
    var saltareTypography: SaltareTypography {
        get { self[SaltareTypographyKey.self] }
        set { self[SaltareTypographyKey.self] = newValue }
    }
    var saltareSpacing: SaltareSpacing {
        get { self[SaltareSpacingKey.self] }
        set { self[SaltareSpacingKey.self] = newValue }
    }
    var hudContentColor: Color? {
        get { self[HudContentColorKey.self] }
        set { self[HudContentColorKey.self] = newValue }
    }
    var hudTextStyle: HudTextStyle? {
        get { self[HudTextStyleKey.self] }
        set { self[HudTextStyleKey.self] = newValue }
    }
}

// MARK: - Theme root

public extension View {
    /// Root of the Saltare design system. Dark is the system's identity — it
    /// does not follow the platform appearance by default; pass
    /// `SaltareColors.light` explicitly for the parchment theme.
    ///
    /// Mirrors the Android `SaltareTheme`: injects the palettes, sets the
    /// default content color to `frost`, and seeds the ambient text style with
    /// `body`.
    func saltareTheme(
        colors: SaltareColors = .dark,
        typography: SaltareTypography = SaltareTypography(),
        spacing: SaltareSpacing = SaltareSpacing()
    ) -> some View {
        environment(\.saltareColors, colors)
            .environment(\.saltareTypography, typography)
            .environment(\.saltareSpacing, spacing)
            .environment(\.hudContentColor, colors.frost)
            .environment(\.hudTextStyle, typography.body)
            .tint(colors.arc)
    }

    /// Merge a text style into the ambient one for descendant `HudText`.
    func hudTextStyle(_ style: HudTextStyle) -> some View {
        environment(\.hudTextStyle, style)
    }

    /// Set the ambient content color for descendant `HudText` / icons.
    func hudContentColor(_ color: Color) -> some View {
        environment(\.hudContentColor, color)
    }
}
