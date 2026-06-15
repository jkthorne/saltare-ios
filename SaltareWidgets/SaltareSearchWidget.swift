import WidgetKit
import SwiftUI
import SaltareHUD

struct SaltareEntry: TimelineEntry {
    let date: Date
}

/// Static — the widget has no data, it's a launch point. One entry, never
/// refreshed.
struct SaltareProvider: TimelineProvider {
    func placeholder(in context: Context) -> SaltareEntry { SaltareEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (SaltareEntry) -> Void) {
        completion(SaltareEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SaltareEntry>) -> Void) {
        completion(Timeline(entries: [SaltareEntry(date: Date())], policy: .never))
    }
}

/// A Home/Lock-Screen widget that deep-links into the universal input.
struct SaltareSearchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ai.saltare.widget.search", provider: SaltareProvider()) { _ in
            SaltareWidgetView()
                .widgetURL(URL(string: "saltare://search"))
        }
        .configurationDisplayName("saltare")
        .description("Open the universal input.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

private struct SaltareWidgetView: View {
    @Environment(\.widgetFamily) private var family
    private let colors = SaltareColors.dark

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\u{25C6} saltare")

        case .accessoryRectangular:
            HStack(spacing: 6) {
                NierMarker(status: .active, size: .md)
                HudText("SALTARE", style: HudTextStyle(family: .mono, size: 13, weight: .semibold, trackingEm: 0.16))
            }
            .saltareTheme(colors: colors)

        default: // systemSmall
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    NierDiamond(color: colors.arc, size: 16)
                    HudText("SALTARE", color: colors.frost,
                            style: HudTextStyle(family: .mono, size: 13, weight: .semibold, trackingEm: 0.18))
                }
                Spacer()
                HudText("Search, calc,\nor ask the agent", color: colors.silver,
                        style: HudTextStyle(family: .mono, size: 11, weight: .regular, trackingEm: 0.02))
                ScanBar()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .saltareTheme(colors: colors)
        }
    }
}

#Preview(as: .systemSmall) {
    SaltareSearchWidget()
} timeline: {
    SaltareEntry(date: Date())
}
