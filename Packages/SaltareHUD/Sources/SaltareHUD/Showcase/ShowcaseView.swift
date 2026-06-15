import SwiftUI

/// A component gallery mirroring the web app's `/design` page and the Android
/// `:showcase` module. Drop it into a scroll view inside `.saltareTheme(...)`.
public struct ShowcaseView: View {
    @Environment(\.saltareColors) private var colors

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                NierHeading("Identity")
                HStack(spacing: 12) {
                    NierDiamond(color: colors.arc, size: 28)
                    HudText("SALTARE", style: HudTextStyle(family: .mono, size: 18, weight: .semibold, trackingEm: 0.22))
                }
                ScanBar()

                NierHeading("Buttons")
                HStack(spacing: 10) {
                    HudButton("Primary", variant: .primary) {}
                    HudButton("Secondary", variant: .secondary) {}
                }
                HStack(spacing: 10) {
                    HudButton("Danger", variant: .danger) {}
                    HudButton("Ghost", variant: .ghost) {}
                    HudButton("Off", enabled: false) {}
                }

                NierHeading("Markers & Badges")
                HStack(spacing: 14) {
                    NierMarker(status: .idle, size: .lg)
                    NierMarker(status: .active, size: .lg)
                    NierMarker(status: .warning, size: .lg)
                    NierMarker(status: .danger, size: .lg)
                    NierMarker(status: .success, size: .lg)
                }
                HStack(spacing: 8) {
                    Badge("Neutral")
                    Badge("Online", tone: .materia)
                    Badge("Warn", tone: .limit)
                    Badge("Down", tone: .phoenix)
                    Badge("Arc", tone: .arc)
                }

                NierHeading("Readouts")
                HStack(spacing: 28) {
                    NierReadout(value: "42", label: "Open Tasks")
                    NierReadout(value: "7", label: "Agents", size: .sm)
                    NierReadout(value: "0", label: "Errors", tone: .zero)
                }

                NierHeading("Task States")
                HStack(spacing: 4) {
                    NierCheck(state: .open)
                    NierCheck(state: .progress)
                    NierCheck(state: .waiting)
                    NierCheck(state: .done)
                    NierCheck(state: .cancelled)
                }

                NierHeading("Panels")
                HudPanel(accent: .arc) {
                    VStack(alignment: .leading, spacing: 6) {
                        HudText("HUD PANEL", style: HudTextStyle(family: .mono, size: 11, weight: .semibold, trackingEm: 0.14))
                        HudText("Translucent surface, hairline border, chrome corner brackets.")
                    }
                }
                NierPanel {
                    HudText("NIER PANEL — frost brackets, prominent for dossiers & transmissions.")
                }
                CutPanel(compact: true) {
                    HudText("CUT PANEL — all four corners.")
                }

                NierHeading("Inputs")
                ShowcaseField()

                HudDivider()
                HStack {
                    NierMarker(status: .active, size: .sm)
                    NierTimestamp("M06.14 / 15:01:22")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colors.abyss)
    }
}

private struct ShowcaseField: View {
    @State private var text = ""
    var body: some View {
        HudTextField(
            text: $text,
            label: "Universal Input",
            placeholder: "Search, calc, or ask the agent…",
            hint: "Deterministic search first; the agent is the escalation."
        )
    }
}

#Preview("Dark") {
    ShowcaseView().saltareTheme(colors: .dark)
}

#Preview("Parchment") {
    ShowcaseView().saltareTheme(colors: .light)
}
