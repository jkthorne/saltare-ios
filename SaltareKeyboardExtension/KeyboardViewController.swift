import SwiftUI
import UIKit
import SaltareKeyboard

/// The keyboard extension's principal class: the only file here that talks to
/// UIKit's input machinery. It reads the field's traits, hosts the SwiftUI HUD
/// keyboard, and hands `KeyboardModel` a gateway onto the document — the input
/// rule itself lives in the `SaltareKeyboard` package, which knows nothing about
/// any of this.
final class KeyboardViewController: UIInputViewController {

    private let model = KeyboardModel()
    private var gateway: TextDocumentGateway?
    /// The field the current session was resolved for, so text changes don't
    /// restart a session that is already running (see `textDidChange`).
    private var sessionField: EditorTraits?

    override func viewDidLoad() {
        super.viewDidLoad()
        let gateway = TextDocumentGateway(proxy: { [weak self] in self?.textDocumentProxy })
        self.gateway = gateway
        model.gateway = gateway
        model.switchKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        installHostingController()
        loadWordList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        KeyFeedback.hasFullAccess = hasFullAccess
        // Only offered while other keyboards are installed — a globe key that
        // leads nowhere is worse than no globe key.
        model.needsGlobe = needsInputModeSwitchKey
        startSession()
    }

    /// Fires on every keystroke, ours included, and also when the host moves
    /// focus to another field. Restarting on the former would wipe the word
    /// being typed, so the session only restarts when the *field* changed.
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        let traits = currentTraits()
        if field(of: traits) != sessionField {
            startSession()
            return
        }
        model.dropComposingIfDetached(from: textDocumentProxy.documentContextBeforeInput)
    }

    private func startSession() {
        let traits = currentTraits()
        sessionField = field(of: traits)
        gateway?.reset()
        model.startSession(traits)
    }

    // MARK: - The UIKit edge

    private func currentTraits() -> EditorTraits {
        let proxy = textDocumentProxy
        return EditorTraits(
            keyboard: KeyboardKind(proxy.keyboardType ?? .default),
            returnKey: ReturnKey(proxy.returnKeyType ?? .default),
            capitalization: Capitalization(proxy.autocapitalizationType ?? .sentences),
            correction: Correction(proxy.autocorrectionType ?? .default),
            secure: proxy.isSecureTextEntry ?? false,
            hasTextBefore: !(proxy.documentContextBeforeInput ?? "").isEmpty
        )
    }

    /// The traits that identify the field, with the one that changes as you type
    /// (`hasTextBefore`) held constant.
    private func field(of traits: EditorTraits) -> EditorTraits {
        EditorTraits(
            keyboard: traits.keyboard,
            returnKey: traits.returnKey,
            capitalization: traits.capitalization,
            correction: traits.correction,
            secure: traits.secure,
            hasTextBefore: false
        )
    }

    private func installHostingController() {
        let host = UIHostingController(rootView: KeyboardRootView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        // An input view has no intrinsic height; 999 rather than required so it
        // yields to the system's own layout during rotation instead of breaking.
        let height = view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.height)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    /// 30k lines of word list, off the main thread: the keyboard must be usable
    /// the moment it appears, and suggestions can arrive a beat later.
    private func loadWordList() {
        let model = self.model
        Task.detached(priority: .userInitiated) {
            guard let dictionary = WordList.bundled() else { return }
            await model.adopt(Suggester(dictionary: dictionary))
        }
    }
}

/// The standard keyboard click. Unlike haptics it needs no Full Access, and it
/// honours the user's keyboard-click setting.
extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
