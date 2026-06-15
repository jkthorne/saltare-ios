import SwiftUI
import SaltareHUD
import SaltareKit

/// Renders one `SearchResult`. Every case is handled — a compile-enforced touch
/// point, mirroring the Android `DrawerSheet` contract. Each row is a button so
/// it picks up the `HudIndicationStyle` press feel; the per-row *actions*
/// (launch, copy, contacts, agent) are wired in iP1.2 / iP2 — for now selection
/// routes through a single placeholder.
struct CommandRow: View {
    let result: SearchResult
    let onSelect: (SearchResult) -> Void

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    var body: some View {
        Button { onSelect(result) } label: {
            HStack(spacing: 12) {
                content
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
    }

    @ViewBuilder private var content: some View {
        switch result {
        case let .calc(expression, _):
            NierMarker(status: .active, size: .sm)
            HudText(expression, color: colors.silver, style: typo.monoBody)

        case let .appHit(app):
            NierMarker(status: .idle, size: .sm)
            HudText(app.displayLabel, color: colors.frost, style: typo.body)

        case let .settingsLink(def):
            NierMarker(status: .idle, size: .sm)
            HudText(def.label, color: colors.frost, style: typo.body)

        case let .contact(name, number):
            NierMarker(status: .idle, size: .sm)
            HudText(name, color: colors.frost, style: typo.body)
            HudText(number, color: colors.silver, style: typo.monoBody)

        case .contactsGrant:
            NierMarker(status: .warning, size: .sm)
            HudText("Allow Contacts", color: colors.limit, style: typo.body)

        case let .agentStub(query):
            Badge("Ask Agent", tone: .arc)
            HudText("\u{201C}\(query)\u{201D}", color: colors.frost, style: typo.body)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch result {
        case let .calc(_, display):
            HudText("= \(display)", color: colors.arcBright, style: typo.monoBody)
        case .appHit:
            HudText("GO", color: colors.silver, style: typo.hudLabelSmall)
        case .settingsLink:
            Badge("Settings")
        case .contact:
            Badge("Call", tone: .materia)
        case .contactsGrant:
            HudText("GRANT", color: colors.limit, style: typo.hudLabelSmall)
        case .agentStub:
            HudText("\u{2192}", color: colors.arc, style: typo.monoBody)
        }
    }
}
