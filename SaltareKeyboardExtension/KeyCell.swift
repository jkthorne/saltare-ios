import Foundation
import SwiftUI
import SaltareHUD

/// A key's border, when it has one (the shift key's arc outline).
struct KeyStroke {
    let color: Color
    let width: CGFloat
}

/// Hold timings. The cadence accelerates the way every platform's key repeat
/// does, so holding backspace clears a line without clearing the paragraph.
enum KeyTiming {
    static let holdDelay: Duration = .milliseconds(400)
    static let minimumInterval: Duration = .milliseconds(40)
    static let acceleration = 0.85
}

/// Owns one key's repeat timer, so the `KeyCell` view never has to hold a
/// `Task` itself. Being a `@MainActor` class makes it safe to capture in the
/// task it starts; a `View` struct would not be.
@MainActor
final class KeyPressRepeater {

    private var task: Task<Void, Never>?
    /// Set once a hold has fired: lifting the finger must not then also tap.
    private var consumed = false

    nonisolated init() {}

    func press(hold: (@MainActor () -> Void)?, repeats: Bool, immediately: Bool) {
        task?.cancel()
        consumed = false
        guard let hold else { return }
        if immediately {
            consumed = true
            hold()
        }
        task = Task { [weak self] in
            var delay = KeyTiming.holdDelay
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.consumed = true
            hold()
            guard repeats else { return }
            while !Task.isCancelled {
                delay = max(KeyTiming.minimumInterval, delay * KeyTiming.acceleration)
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                hold()
            }
        }
    }

    /// Ends the press, and reports whether the tap should still fire.
    func release() -> Bool {
        task?.cancel()
        task = nil
        let fired = consumed
        consumed = false
        return !fired
    }
}

/// The press behaviour every key shares, as one gesture rather than a `Button`:
/// a keyboard wants feedback on touch-down, a long press that suppresses the tap
/// (alternates), and a hold that repeats (backspace). A `Button` with a
/// simultaneous long-press gesture fires both, which is how a keyboard types
/// `q1` when you asked for `1`.
struct KeyCell<Label: View>: View {
    private let surface: Color
    private let stroke: KeyStroke?
    private let hold: (@MainActor () -> Void)?
    private let holdRepeats: Bool
    private let firesOnPress: Bool
    private let tap: @MainActor () -> Void
    private let label: () -> Label

    @Environment(\.saltareColors) private var colors
    @State private var pressed = false
    @State private var repeater = KeyPressRepeater()

    init(
        surface: Color,
        stroke: KeyStroke? = nil,
        hold: (@MainActor () -> Void)? = nil,
        holdRepeats: Bool = false,
        firesOnPress: Bool = false,
        tap: @escaping @MainActor () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.surface = surface
        self.stroke = stroke
        self.hold = hold
        self.holdRepeats = holdRepeats
        self.firesOnPress = firesOnPress
        self.tap = tap
        self.label = label
    }

    var body: some View {
        label()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pressed ? colors.panelActive : surface)
            .overlay {
                if let stroke {
                    Rectangle().strokeBorder(stroke.color, lineWidth: stroke.width)
                }
            }
            .contentShape(Rectangle())
            .gesture(press)
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !pressed else { return }
                pressed = true
                KeyFeedback.keyPress()
                repeater.press(hold: hold, repeats: holdRepeats, immediately: firesOnPress)
            }
            .onEnded { _ in
                pressed = false
                if repeater.release() { tap() }
            }
    }
}
