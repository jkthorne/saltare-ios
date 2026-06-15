import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// The Share extension's principal class: pulls the shared text/URL out of the
/// extension context, then hosts the SwiftUI `ShareView` (the HUD form that posts
/// to a channel or creates a task). Completing/cancelling closes the sheet.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        Task { await presentForm() }
    }

    private func presentForm() async {
        let content = await extractContent()
        let root = ShareView(
            text: content.text,
            url: content.url,
            onComplete: { [weak self] in self?.finish(cancelled: false) },
            onCancel: { [weak self] in self?.finish(cancelled: true) }
        )
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func extractContent() async -> (text: String?, url: String?) {
        var text: String?
        var url: String?
        for case let item as NSExtensionItem in extensionContext?.inputItems ?? [] {
            for provider in item.attachments ?? [] {
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    url = await loadString(provider, UTType.url.identifier)
                } else if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    text = await loadString(provider, UTType.plainText.identifier)
                }
            }
            if text == nil, let attributed = item.attributedContentText?.string, !attributed.isEmpty {
                text = attributed
            }
        }
        return (text, url)
    }

    private func loadString(_ provider: NSItemProvider, _ typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { value, _ in
                switch value {
                case let url as URL: continuation.resume(returning: url.absoluteString)
                case let string as String: continuation.resume(returning: string)
                case let data as Data: continuation.resume(returning: String(data: data, encoding: .utf8))
                default: continuation.resume(returning: nil)
                }
            }
        }
    }

    private func finish(cancelled: Bool) {
        if cancelled {
            extensionContext?.cancelRequest(withError: NSError(domain: "ai.saltare.share", code: 0))
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
