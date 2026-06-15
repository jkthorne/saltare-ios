import WidgetKit
import SwiftUI
import ActivityKit
import SaltareHUD

/// The Lock Screen + Dynamic Island presentation of a running agent turn. The
/// app drives `AgentActivityAttributes.ContentState`; this only renders it
/// (HUD-styled, like the other widgets). Deep-links into the agent on tap.
struct AgentLiveActivityWidget: Widget {
    private let colors = SaltareColors.dark

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentActivityAttributes.self) { context in
            lockScreen(context.attributes.title, context.state)
                .padding(14)
                .activityBackgroundTint(colors.abyss)
                .activitySystemActionForegroundColor(colors.frost)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        NierMarker(status: context.state.isActive ? .active : .filled, size: .md)
                        HudText(context.attributes.title, color: colors.frost,
                                style: HudTextStyle(family: .mono, size: 13, weight: .semibold, trackingEm: 0.16))
                    }
                    .saltareTheme(colors: colors)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HudText(context.state.statusLabel, color: colors.arc,
                            style: HudTextStyle(family: .mono, size: 12, weight: .medium, trackingEm: 0.14))
                        .saltareTheme(colors: colors)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HudText(context.state.detail, color: colors.silver,
                            style: HudTextStyle(family: .mono, size: 12, weight: .regular, trackingEm: 0.02))
                        .saltareTheme(colors: colors)
                }
            } compactLeading: {
                NierDiamond(color: context.state.isActive ? colors.arc : colors.silver, size: 12)
            } compactTrailing: {
                HudText(context.state.statusLabel, color: colors.arc,
                        style: HudTextStyle(family: .mono, size: 11, weight: .medium, trackingEm: 0.1))
                    .saltareTheme(colors: colors)
            } minimal: {
                NierDiamond(color: context.state.isActive ? colors.arc : colors.silver, size: 12)
            }
            .widgetURL(URL(string: "saltare://agent"))
        }
    }

    private func lockScreen(_ title: String, _ state: AgentActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                NierMarker(status: state.isActive ? .active : .filled, size: .md)
                HudText(title, color: colors.frost,
                        style: HudTextStyle(family: .mono, size: 14, weight: .semibold, trackingEm: 0.18))
                Spacer()
                HudText(state.statusLabel, color: colors.arc,
                        style: HudTextStyle(family: .mono, size: 12, weight: .medium, trackingEm: 0.14))
            }
            HudText(state.detail, color: colors.silver,
                    style: HudTextStyle(family: .mono, size: 12, weight: .regular, trackingEm: 0.02))
            if state.isActive { ScanBar() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .saltareTheme(colors: colors)
    }
}
