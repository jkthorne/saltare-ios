import SwiftUI
import CoreText

/// The two type faces. Geist is the display face; Geist Mono is the HUD face
/// (all technical readouts, labels, and buttons).
public enum HudFontFamily: Sendable {
    case display
    case mono
}

/// Resolves `(family, weight)` to the bundled Geist face and registers the
/// fonts with CoreText on first use. Fonts ship inside the package bundle, so
/// they must be registered for the process — `Font.custom` alone won't find
/// them.
public enum SaltareFont {

    /// Registered exactly once, lazily, the first time any style resolves.
    private static let registered: Bool = {
        register()
        return true
    }()

    public static func resolve(family: HudFontFamily, size: CGFloat, weight: Font.Weight) -> Font {
        _ = registered
        return Font.custom(postScriptName(family, weight), fixedSize: size)
    }

    /// The web mono system never loads above 500; a requested 600 renders the
    /// medium cut (matching the Android note in `SaltareTypography`).
    static func postScriptName(_ family: HudFontFamily, _ weight: Font.Weight) -> String {
        switch family {
        case .display:
            switch weight {
            case .bold, .heavy, .black: return "Geist-Bold"
            case .semibold: return "Geist-SemiBold"
            case .medium: return "Geist-Medium"
            default: return "Geist-Regular"
            }
        case .mono:
            switch weight {
            case .medium, .semibold, .bold, .heavy, .black: return "GeistMono-Medium"
            default: return "GeistMono-Regular"
            }
        }
    }

    /// Register every bundled `.ttf`. Idempotent: CoreText returns an
    /// already-registered error we deliberately ignore.
    public static func register() {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else {
            return
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
