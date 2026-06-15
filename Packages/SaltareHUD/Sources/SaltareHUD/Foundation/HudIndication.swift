import SwiftUI

/// The design system's ripple replacement, as a `ButtonStyle`. Every HUD
/// control routes through it so press/focus behave identically — the SwiftUI
/// analog of wiring `HudIndication` into `LocalIndication`.
///
/// CSS semantics:
///  - press  → `transform: scale(0.98)`
///  - focus  → 2px accent outline, 2px offset (`:focus-visible`)
public struct HudIndicationStyle: ButtonStyle {
    let focusColor: Color
    let enabled: Bool

    public init(focusColor: Color, enabled: Bool = true) {
        self.focusColor = focusColor
        self.enabled = enabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: configuration.isPressed ? 0.1 : 0.15), value: configuration.isPressed)
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

/// A focus ring matching CSS `:focus-visible` (2px outline, 2px offset). Apply
/// to focusable HUD surfaces; the ring sits just outside the bounds.
public struct HudFocusRing: ViewModifier {
    let color: Color
    let focused: Bool

    public func body(content: Content) -> some View {
        content.overlay {
            if focused {
                Rectangle()
                    .strokeBorder(color, lineWidth: 2)
                    .padding(-4) // 2px offset + 2px stroke, outside the bounds
                    .allowsHitTesting(false)
            }
        }
    }
}

public extension View {
    func hudFocusRing(_ color: Color, focused: Bool) -> some View {
        modifier(HudFocusRing(color: color, focused: focused))
    }
}
