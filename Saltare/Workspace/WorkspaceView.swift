import SwiftUI
import SaltareHUD
import SaltareWorkspace

/// The workspace browser — Chat, Tasks, Agents, Documents over the REST client.
/// Falls back to sign-in when signed out (it observes the session, so it swaps
/// to the tabs once you sign in).
struct WorkspaceView: View {
    @Bindable var session: WorkspaceSession
    @State private var store: WorkspaceStore
    @State private var tab: WorkspaceTab = .channels
    private let demoMode: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    @MainActor
    init(session: WorkspaceSession) {
        self.session = session
        let demo = ProcessInfo.processInfo.environment["SALTARE_DEMO"] != nil
        self.demoMode = demo
        _store = State(initialValue: demo ? .demo(client: session.client) : WorkspaceStore(client: session.client))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.abyss.ignoresSafeArea()
                if session.isSignedIn || demoMode { signedIn } else { SignInView(session: session) }
            }
            .navigationBarHidden(true)
        }
        .saltareTheme(colors: .dark)
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                NierMarker(status: .active, size: .lg)
                HudText((session.stored?.workspaceName ?? "Workspace").uppercased(), color: colors.frost,
                        style: HudTextStyle(family: .mono, size: 15, weight: .semibold, trackingEm: 0.18))
                Spacer()
                Button { dismiss() } label: { HudText("DONE", color: colors.silver, style: typo.hudLabelSmall) }
                    .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
            }
            tabBar
            content
        }
        .padding(16)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(WorkspaceTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    HudText(item.label, color: tab == item ? colors.arc : colors.silver, style: typo.hudLabelSmall)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(Rectangle().strokeBorder(tab == item ? colors.arc : colors.panelBorder, lineWidth: 1))
                }
                .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .channels:
            LoadableList(state: store.channels, load: { await store.loadChannels() }, empty: "No channels.") { channel in
                NavigationLink {
                    ChannelThreadView(channel: channel, client: store.client, realtime: demoMode ? nil : session.realtime)
                } label: { channelRow(channel) }
            }
        case .tasks:
            LoadableList(state: store.tasks, load: { await store.loadTasks() }, empty: "No tasks.") { task in taskRow(task) }
        case .agents:
            LoadableList(state: store.agents, load: { await store.loadAgents() }, empty: "No agents.") { agent in agentRow(agent) }
        case .documents:
            LoadableList(state: store.documents, load: { await store.loadDocuments() }, empty: "No documents.") { document in
                NavigationLink { DocumentDetailView(document: document) } label: { documentRow(document) }
            }
        }
    }

    // MARK: - rows

    private func channelRow(_ channel: Channel) -> some View {
        HStack(spacing: 10) {
            NierMarker(status: channel.archived ? .idle : .filled, size: .sm)
            HudText("#\(channel.name ?? channel.slug)", color: colors.frost, style: typo.body)
            Spacer()
            HudText("\(channel.messagesCount ?? 0)", color: colors.silver, style: typo.monoBody)
        }.contentShape(Rectangle())
    }

    private func taskRow(_ task: WorkspaceTask) -> some View {
        HStack(spacing: 10) {
            NierCheck(state: Self.checkState(task.state))
            VStack(alignment: .leading, spacing: 2) {
                HudText(task.title, color: colors.frost, style: typo.body)
                if let due = task.dueDate { HudText(due, color: colors.silver, style: typo.timestamp) }
            }
            Spacer()
        }
    }

    private func agentRow(_ agent: Agent) -> some View {
        HStack(spacing: 10) {
            NierMarker(status: agent.status == "active" ? .active : .idle, size: .sm)
            HudText(agent.name, color: colors.frost, style: typo.body)
            Spacer()
            if let model = agent.model { Badge(model, tone: .arc) }
        }
    }

    private func documentRow(_ document: Document) -> some View {
        HStack(spacing: 10) {
            NierMarker(status: .idle, size: .sm)
            HudText(document.title, color: colors.frost, style: typo.body)
            Spacer()
            if document.published { Badge("Published", tone: .materia) }
        }.contentShape(Rectangle())
    }

    private static func checkState(_ state: String) -> CheckState {
        switch state {
        case "in_progress": .progress
        case "waiting": .waiting
        case "completed": .done
        case "cancelled": .cancelled
        default: .open
        }
    }
}

enum WorkspaceTab: CaseIterable, Hashable {
    case channels, tasks, agents, documents
    var label: String {
        switch self {
        case .channels: "CHAT"
        case .tasks: "TASKS"
        case .agents: "AGENTS"
        case .documents: "DOCS"
        }
    }
}

/// Generic loadable list — handles loading / error / empty / loaded, loads on appear.
private struct LoadableList<Item: Identifiable, Row: View>: View {
    let state: Loadable<[Item]>
    let load: () async -> Void
    let empty: String
    @ViewBuilder let row: (Item) -> Row

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    var body: some View {
        ScrollView {
            switch state {
            case .idle, .loading:
                VStack(spacing: 10) { ScanBar(); HudText("Loading\u{2026}", color: colors.silver, style: typo.monoBody) }
                    .frame(maxWidth: .infinity).padding(.top, 40)
            case let .failed(message):
                HudText(message, color: colors.phoenix, style: typo.monoBody)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().strokeBorder(colors.phoenixDim, lineWidth: 1))
            case let .loaded(items):
                if items.isEmpty {
                    HudText(empty, color: colors.silver, style: typo.monoBody).padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            row(item).padding(.vertical, 10)
                            HudDivider()
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .task { await load() }
    }
}

/// One channel's messages + composer.
private struct ChannelThreadView: View {
    let channel: Channel
    let client: WorkspaceClient
    @State private var model: ChannelThreadModel

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    @MainActor
    init(channel: Channel, client: WorkspaceClient, realtime: RealtimeClient? = nil) {
        self.channel = channel
        self.client = client
        _model = State(initialValue: ChannelThreadModel(channel: channel, client: client, realtime: realtime))
    }

    var body: some View {
        ZStack {
            colors.abyss.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    HudText("#\(channel.name ?? channel.slug)".uppercased(), color: colors.frost, style: typo.hudLabel)
                    if model.live { Badge("LIVE", tone: .materia) }
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(model.messages.value ?? []) { message in messageRow(message) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                if model.messages.isLoading { ScanBar() }
                composer
            }
            .padding(16)
        }
        .saltareTheme(colors: .dark)
        .task { await model.load() }
        .task { await model.streamLive() } // held open while on screen; cancels on disappear
    }

    private func messageRow(_ message: Message) -> some View {
        let isAgent = message.sender.type == "Agent"
        return HStack(alignment: .top, spacing: 8) {
            NierMarker(status: isAgent ? .active : .idle, size: .sm).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HudText(isAgent ? "AGENT" : "USER", color: isAgent ? colors.arc : colors.silver, style: typo.hudLabelSmall)
                HudText(message.body ?? "", color: colors.ice, style: typo.body)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            HudTextField(text: $model.draft, placeholder: "Message\u{2026}")
            HudButton("Send", enabled: !model.sending) { Task { await model.send() } }
        }
    }
}

/// A document's body.
private struct DocumentDetailView: View {
    let document: Document
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    var body: some View {
        ZStack {
            colors.abyss.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HudText(document.title, color: colors.frost,
                            style: HudTextStyle(family: .display, size: 20, weight: .semibold))
                    HudDivider()
                    HudText(document.body ?? "(empty)", color: colors.ice, style: typo.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .saltareTheme(colors: .dark)
    }
}
