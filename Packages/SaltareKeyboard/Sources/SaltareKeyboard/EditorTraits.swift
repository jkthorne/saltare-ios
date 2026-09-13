/// A UIKit-free mirror of the field's `UITextInputTraits`, so the policy that
/// reads them (`EditorContext`) stays pure and table-testable. The extension
/// maps `UIKeyboardType` / `UIReturnKeyType` / `UITextAutocapitalizationType` /
/// `UITextAutocorrectionType` onto these at the edge — a `switch` over named
/// cases rather than the raw values, which Apple does not document as stable.
public struct EditorTraits: Equatable, Sendable {
    public let keyboard: KeyboardKind
    public let returnKey: ReturnKey
    public let capitalization: Capitalization
    public let correction: Correction
    public let secure: Bool
    /// Whether the field already has text before the cursor — the auto-capitalize
    /// seed only applies to an empty field.
    public let hasTextBefore: Bool

    public init(
        keyboard: KeyboardKind = .default,
        returnKey: ReturnKey = .default,
        capitalization: Capitalization = .sentences,
        correction: Correction = .default,
        secure: Bool = false,
        hasTextBefore: Bool = false
    ) {
        self.keyboard = keyboard
        self.returnKey = returnKey
        self.capitalization = capitalization
        self.correction = correction
        self.secure = secure
        self.hasTextBefore = hasTextBefore
    }
}

/// `UIKeyboardType`.
public enum KeyboardKind: Equatable, Sendable, CaseIterable {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case url
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad

    /// Fields that want digits, not letters — they open on the numeric page.
    /// `namePhonePad` is not one: it is a name field that also accepts digits.
    public var isNumeric: Bool {
        switch self {
        case .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad: true
        default: false
        }
    }

    /// Fields whose contents are not prose, so a dictionary would fight the user.
    public var isStructured: Bool {
        switch self {
        case .url, .emailAddress: true
        default: false
        }
    }
}

/// `UIReturnKeyType`.
public enum ReturnKey: Equatable, Sendable, CaseIterable {
    case `default`
    case go
    case google
    case join
    case next
    case route
    case search
    case send
    case yahoo
    case done
    case emergencyCall
    case `continue`
}

/// `UITextAutocapitalizationType`.
public enum Capitalization: Equatable, Sendable, CaseIterable {
    case none
    case words
    case sentences
    case allCharacters
}

/// `UITextAutocorrectionType`.
public enum Correction: Equatable, Sendable, CaseIterable {
    case `default`
    case no
    case yes
}
