import Foundation
import SwiftUI
import SaltareHUD
import SaltareKeyboard

/// Renders one key. Keycaps are always uppercase (the locked design decision);
/// shift state shows on the shift key as an arc border plus a caps-lock marker,
/// the way the Android `KeyView` does it. Width comes from the row (see
/// `KeyboardRootView`), so nothing here sets its own size.
struct KeyView: View {
    let key: Key
    let model: KeyboardModel

    @Environment(\.saltareColors) private var colors
    private let typography = SaltareTypography()

    var body: some View {
        switch key {
        case let .character(character, alternates):
            characterKey(character, alternate: alternates.first)
        case let .page(target, label):
            plainKey(label) { model.handle(.pageSwitched(target)) }
        case .shift:
            shiftKey
        case .backspace:
            backspaceKey
        case .space:
            plainKey("SALTARE", style: typography.hudLabelSmall) { model.handle(.spaceTapped) }
                .accessibilityLabel("Space")
        case .enter:
            plainKey(model.state.enter.label, surface: colors.arc, color: colors.void) {
                model.handle(.enterTapped)
            }
        case .globe:
            plainKey("◍") { model.switchKeyboard?() }
                .accessibilityLabel("Next keyboard")
        }
    }

    private func characterKey(_ character: Character, alternate: Character?) -> some View {
        var hold: (@MainActor () -> Void)?
        if let alternate {
            hold = { model.handle(.alternateCommitted(alternate)) }
        }
        return KeyCell(
            surface: colors.graphite,
            hold: hold,
            tap: { model.handle(.keyTapped(character)) }
        ) {
            HudText(
                String(character).uppercased(),
                color: colors.frost,
                style: HudTextStyle(family: .mono, size: 18, weight: .medium, trackingEm: 0.04)
            )
        }
        .accessibilityLabel(String(character))
    }

    private var backspaceKey: some View {
        KeyCell(
            surface: colors.steel,
            hold: { model.handle(.backspaceTapped) },
            holdRepeats: true,
            firesOnPress: true,
            tap: { model.handle(.backspaceTapped) }
        ) {
            HudText("⌫", color: colors.silver, style: typography.hudLabel)
        }
        .accessibilityLabel("Delete")
    }

    private var shiftKey: some View {
        let surface: Color
        let stroke: KeyStroke?
        let glyph: Color
        switch model.state.shift {
        case .off:
            surface = colors.steel
            stroke = nil
            glyph = colors.silver
        case .shifted:
            surface = colors.arcSubtle
            stroke = KeyStroke(color: colors.arc, width: 1)
            glyph = colors.arc
        case .capsLock:
            surface = colors.arcSubtle
            stroke = KeyStroke(color: colors.arcBright, width: 1.5)
            glyph = colors.arcBright
        }
        let locked = model.state.shift == .capsLock
        return KeyCell(
            surface: surface,
            stroke: stroke,
            // The clock is read here and handed to the reducer, which never
            // reads one itself — that is what makes double-tap testable.
            tap: { model.handle(.shiftTapped(now: Date.timeIntervalSinceReferenceDate)) }
        ) {
            ZStack(alignment: .topTrailing) {
                HudText("⇧", color: glyph, style: typography.hudLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if locked {
                    NierMarker(status: .active, size: .xs).padding(3)
                }
            }
        }
        .accessibilityLabel(shiftDescription)
    }

    private var shiftDescription: String {
        switch model.state.shift {
        case .off: "Shift"
        case .shifted: "Shift on"
        case .capsLock: "Caps lock on"
        }
    }

    private func plainKey(
        _ label: String,
        surface: Color? = nil,
        color: Color? = nil,
        style: HudTextStyle? = nil,
        tap: @escaping @MainActor () -> Void
    ) -> some View {
        KeyCell(surface: surface ?? colors.steel, tap: tap) {
            HudText(label, color: color ?? colors.silver, style: style ?? typography.hudLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
