/// Off → the next letter is lowercase. Shifted → one uppercase letter, then
/// back to off. CapsLock → uppercase until toggled off (entered by
/// double-tapping shift).
public enum ShiftState: Equatable, Sendable, CaseIterable {
    case off
    case shifted
    case capsLock
}
