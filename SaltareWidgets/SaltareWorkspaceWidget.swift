import WidgetKit
import SwiftUI
import SaltareHUD
import SaltareWorkspace

/// A medium widget showing recent channels + open tasks, read from the App Group
/// snapshot the app writes (`WorkspaceSnapshotStore`). No network/token in the
/// widget process — it renders the last snapshot and deep-links into the app.
struct WorkspaceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WorkspaceSnapshot?
}

struct WorkspaceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkspaceWidgetEntry {
        WorkspaceWidgetEntry(date: Date(), snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (WorkspaceWidgetEntry) -> Void) {
        completion(WorkspaceWidgetEntry(date: Date(), snapshot: WorkspaceSnapshotStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkspaceWidgetEntry>) -> Void) {
        // The app reloads this timeline when it writes a fresh snapshot, so one
        // entry that never auto-expires is enough.
        let entry = WorkspaceWidgetEntry(date: Date(), snapshot: WorkspaceSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct SaltareWorkspaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SaltareWidgetKind.workspace, provider: WorkspaceWidgetProvider()) { entry in
            WorkspaceWidgetView(entry: entry)
                .widgetURL(URL(string: "saltare://workspace"))
        }
        .configurationDisplayName("Workspace")
        .description("Recent channels and open tasks.")
        .supportedFamilies([.systemMedium])
    }
}

private struct WorkspaceWidgetView: View {
    let entry: WorkspaceWidgetEntry
    private let colors = SaltareColors.dark

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                NierDiamond(color: colors.arc, size: 14)
                HudText((entry.snapshot?.workspaceName ?? "SALTARE").uppercased(), color: colors.frost,
                        style: HudTextStyle(family: .mono, size: 12, weight: .semibold, trackingEm: 0.16))
            }
            if let snapshot = entry.snapshot, !(snapshot.channels.isEmpty && snapshot.tasks.isEmpty) {
                HStack(alignment: .top, spacing: 14) {
                    column("CHANNELS", items: snapshot.channels)
                    column("TASKS", items: snapshot.tasks)
                }
            } else {
                Spacer()
                HudText("Open saltare to sync", color: colors.silver,
                        style: HudTextStyle(family: .mono, size: 11, weight: .regular, trackingEm: 0.02))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .saltareTheme(colors: colors)
    }

    private func column(_ heading: String, items: [WorkspaceSnapshot.Item]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HudText(heading, color: colors.arc,
                    style: HudTextStyle(family: .mono, size: 10, weight: .medium, trackingEm: 0.14))
            ForEach(items.prefix(3)) { item in
                HudText(item.title, color: colors.ice,
                        style: HudTextStyle(family: .mono, size: 11, weight: .regular, trackingEm: 0.02))
                    .lineLimit(1)
            }
            if items.isEmpty {
                HudText("—", color: colors.silver, style: HudTextStyle(family: .mono, size: 11, weight: .regular, trackingEm: 0.02))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
