import UIKit

protocol Pasteboarding: Sendable {
    @MainActor func copy(_ string: String)
}

struct SystemPasteboard: Pasteboarding {
    @MainActor func copy(_ string: String) {
        UIPasteboard.general.string = string
    }
}
