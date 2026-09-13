import UIKit
import SaltareKeyboard

/// The mapping from `UITextInputTraits` onto the package's UIKit-free mirror.
/// Written as exhaustive switches over named cases rather than raw values: the
/// numbers behind `UIKeyboardType` are not documented as stable, and a future
/// case should arrive here as a compiler warning, not as a wrong keyboard.
extension KeyboardKind {
    init(_ type: UIKeyboardType) {
        switch type {
        case .default: self = .default
        case .asciiCapable: self = .asciiCapable
        case .numbersAndPunctuation: self = .numbersAndPunctuation
        case .URL: self = .url
        case .numberPad: self = .numberPad
        case .phonePad: self = .phonePad
        case .namePhonePad: self = .namePhonePad
        case .emailAddress: self = .emailAddress
        case .decimalPad: self = .decimalPad
        case .twitter: self = .twitter
        case .webSearch: self = .webSearch
        case .asciiCapableNumberPad: self = .asciiCapableNumberPad
        @unknown default: self = .default
        }
    }
}

extension ReturnKey {
    init(_ type: UIReturnKeyType) {
        switch type {
        case .default: self = .default
        case .go: self = .go
        case .google: self = .google
        case .join: self = .join
        case .next: self = .next
        case .route: self = .route
        case .search: self = .search
        case .send: self = .send
        case .yahoo: self = .yahoo
        case .done: self = .done
        case .emergencyCall: self = .emergencyCall
        case .continue: self = .continue
        @unknown default: self = .default
        }
    }
}

extension Capitalization {
    init(_ type: UITextAutocapitalizationType) {
        switch type {
        case .none: self = .none
        case .words: self = .words
        case .sentences: self = .sentences
        case .allCharacters: self = .allCharacters
        @unknown default: self = .sentences
        }
    }
}

extension Correction {
    init(_ type: UITextAutocorrectionType) {
        switch type {
        case .default: self = .default
        case .no: self = .no
        case .yes: self = .yes
        @unknown default: self = .default
        }
    }
}
