import Foundation
import Observation
import SaltareWorkspace

/// Loads workspace collections over the REST client. One per `WorkspaceView`.
@MainActor
@Observable
final class WorkspaceStore {
    let client: WorkspaceClient
    private let indexer: SpotlightIndexing?

    var channels: Loadable<[Channel]> = .idle
    var tasks: Loadable<[WorkspaceTask]> = .idle
    var agents: Loadable<[Agent]> = .idle
    var documents: Loadable<[Document]> = .idle

    init(client: WorkspaceClient, indexer: SpotlightIndexing? = nil) {
        self.client = client
        self.indexer = indexer
    }

    /// A store preloaded with sample data — for previews / screenshots (no
    /// network; the `loadX` guards short-circuit on already-loaded state).
    static func demo(client: WorkspaceClient) -> WorkspaceStore {
        let store = WorkspaceStore(client: client)
        func decode<T: Decodable & Sendable>(_ json: String) -> [T] {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return (try? decoder.decode(DataEnvelope<[T]>.self, from: Data(json.utf8)).data) ?? []
        }
        let channelsJSON = #"{"data":[{"id":1,"slug":"general","name":"general","kind":"public_channel","archived":false,"messages_count":214,"members_count":8,"created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},{"id":2,"slug":"engineering","name":"engineering","kind":"public_channel","archived":false,"messages_count":1180,"members_count":5,"created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},{"id":3,"slug":"design","name":"design","kind":"private_channel","archived":false,"messages_count":92,"members_count":3,"created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}]}"#
        let tasksJSON = #"{"data":[{"id":1,"slug":"ship-ios","title":"Ship the iOS app","state":"in_progress","priority":"high","due_date":"2026-06-20","created_at":"2026-06-10T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},{"id":2,"slug":"mcp-tools","title":"Wire MCP saltare tools","state":"open","priority":"medium","created_at":"2026-06-11T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},{"id":3,"slug":"design-review","title":"NieR HUD design review","state":"completed","priority":"low","due_date":"2026-06-12","created_at":"2026-06-09T00:00:00Z","updated_at":"2026-06-12T00:00:00Z"}]}"#
        let agentsJSON = #"{"data":[{"id":1,"slug":"saltare","name":"Saltare","status":"active","model":"claude-opus-4-8","created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},{"id":2,"slug":"researcher","name":"Researcher","status":"active","model":"claude-sonnet-4-6","created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}]}"#
        let documentsJSON = #"{"data":[{"id":1,"slug":"roadmap","title":"saltare-ios roadmap","published":true,"created_at":"2026-06-14T00:00:00Z","updated_at":"2026-06-15T00:00:00Z"},{"id":2,"slug":"api-notes","title":"API integration notes","published":false,"created_at":"2026-06-13T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}]}"#
        store.channels = .loaded(decode(channelsJSON))
        store.tasks = .loaded(decode(tasksJSON))
        store.agents = .loaded(decode(agentsJSON))
        store.documents = .loaded(decode(documentsJSON))
        return store
    }

    func loadChannels(force: Bool = false) async {
        if !force, channels.value != nil { return }
        channels = .loading
        do { channels = .loaded(try await client.channels()) }
        catch { channels = .failed(workspaceErrorText(error)) }
    }
    func loadTasks(force: Bool = false) async {
        if !force, tasks.value != nil { return }
        tasks = .loading
        do {
            let loaded = try await client.tasks()
            tasks = .loaded(loaded)
            indexer?.index(SpotlightIndex.taskEntries(loaded)) // surface tasks in Spotlight
        } catch { tasks = .failed(workspaceErrorText(error)) }
    }
    func loadAgents(force: Bool = false) async {
        if !force, agents.value != nil { return }
        agents = .loading
        do { agents = .loaded(try await client.agents()) }
        catch { agents = .failed(workspaceErrorText(error)) }
    }
    func loadDocuments(force: Bool = false) async {
        if !force, documents.value != nil { return }
        documents = .loading
        do {
            let loaded = try await client.documents()
            documents = .loaded(loaded)
            indexer?.index(SpotlightIndex.documentEntries(loaded)) // surface docs in Spotlight
        } catch { documents = .failed(workspaceErrorText(error)) }
    }
}

/// One channel's message thread + composer. When a `RealtimeClient` is present
/// it subscribes to the channel's Action Cable stream and appends broadcast
/// messages live (deduped against the REST load + optimistic sends).
@MainActor
@Observable
final class ChannelThreadModel {
    let channel: Channel
    private let client: WorkspaceClient
    private let realtime: RealtimeClient?

    var messages: Loadable<[Message]> = .idle
    var draft = ""
    var sending = false
    /// True once the cable subscription is confirmed — drives the LIVE chip.
    private(set) var live = false

    init(channel: Channel, client: WorkspaceClient, realtime: RealtimeClient? = nil) {
        self.channel = channel
        self.client = client
        self.realtime = realtime
    }

    func load() async {
        messages = .loading
        do { messages = .loaded(try await client.messages(channelId: channel.id)) }
        catch { messages = .failed(workspaceErrorText(error)) }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !sending else { return }
        draft = ""
        sending = true
        if let message = try? await client.sendMessage(channelId: channel.id, body: body) {
            ingest(message)
        }
        sending = false
    }

    /// Hold the cable subscription open for as long as the thread is on screen.
    /// Call from the view's `.task` — cancellation (view disappear) closes the
    /// socket. A no-op when realtime is absent (demo / signed out).
    func streamLive() async {
        guard let realtime else { return }
        let identifier = CableIdentifier.messages(channelId: channel.id)
        let events = await realtime.connect()
        await realtime.subscribe(identifier)
        await withTaskCancellationHandler {
            for await event in events {
                switch event {
                case .confirmed: live = true
                case .rejected, .disconnect: live = false
                case let .message(id, payload) where id == identifier:
                    if let message = Self.decodeMessage(payload) { ingest(message) }
                default: break
                }
            }
            live = false
        } onCancel: {
            realtime.disconnect() // finishes the event stream, ending the loop above
        }
    }

    private func ingest(_ message: Message) {
        var current = messages.value ?? []
        guard !current.contains(where: { $0.id == message.id }) else { return }
        current.append(message)
        messages = .loaded(current)
    }

    private static func decodeMessage(_ payload: Data) -> Message? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(ChannelMessageEvent.self, from: payload).data
    }
}
