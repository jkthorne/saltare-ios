import XCTest
@testable import SaltareWorkspace

/// Decodes the server's own golden payloads — `test/fixtures/files/api_golden/`
/// in the saltare repo, copied verbatim into `api_golden/` here.
///
/// `ModelDecodingTests` decodes JSON literals someone typed, which pins what
/// was typed. These pin what the server actually emits: the files are written
/// by the server's own test, so a renamed or dropped key arrives here as a
/// changed fixture rather than as a bug report from a shipped app.
///
/// Two checks per payload:
///
/// 1. **Decode and read real values.** A required property whose key the server
///    dropped throws; an optional one goes quietly nil, which is why the values
///    are asserted rather than just the decode.
/// 2. **Coverage** — every stored property the model declares must have a key
///    in the payload. `JSONDecoder` has no strict mode (unknown keys are always
///    ignored), so `Mirror` supplies the other direction: the model's own
///    property list, compared against the payload's keys.
///
/// Server keys the model has no property for are printed, not failed. A client
/// that decodes less than the server sends is working as intended — half of
/// these six models deliberately ignore fields the iOS app has no use for.
///
/// Regenerate on the server with:
///
///     WRITE_GOLDEN=1 bin/rails test test/serializers/api/v1/golden_payloads_test.rb
///
/// then run `script/sync-goldens.sh` here.
final class GoldenPayloadTests: XCTestCase {

    // The production decoder's strategy, because the production decoder is what
    // has to survive the payload.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private enum GoldenError: Error, CustomStringConvertible {
        case missing(String)

        var description: String {
            switch self {
            case .missing(let name): return "missing golden payload: api_golden/\(name).json"
            }
        }
    }

    // MARK: - Payloads

    func testAgent() throws {
        let agent = try decode(Agent.self, "agent")

        XCTAssertEqual(agent.slug, "researcher-abc123")
        XCTAssertEqual(agent.name, "Researcher")
        XCTAssertEqual(agent.status, "active")
        XCTAssertEqual(agent.avatarColor, "arc")
        XCTAssertNil(agent.model, "the golden agent runs on the workspace default")

        try assertModelCovers(agent, "agent")
    }

    func testChannel() throws {
        let channel = try decode(Channel.self, "channel")

        XCTAssertEqual(channel.slug, "general")
        XCTAssertEqual(channel.name, "General")
        XCTAssertEqual(channel.kind, "public_channel")
        XCTAssertFalse(channel.archived)
        XCTAssertEqual(channel.messagesCount, 2)
        XCTAssertNil(channel.hostType, "a public channel hosts nothing")

        // Note the printed ignore list: the server sends `display_name`, which
        // is the viewer-relative label a DM needs to read as the other person.
        // SaltareWorkspace has no property for it and shows `name` instead.
        try assertModelCovers(channel, "channel")
    }

    func testMessage() throws {
        let message = try decode(Message.self, "message")

        XCTAssertEqual(message.body, "Welcome to the team!")
        XCTAssertEqual(message.sender.type, "User")
        XCTAssertEqual(message.sender.id, 298486374)
        XCTAssertNil(message.systemEvent, "a regular message is not an event")
        XCTAssertNil(message.threadRootMessageId)

        // `ActorRef` is `{type, id}`; the server also sends `sender.name`, so
        // the sender's display name has to come from elsewhere.
        try assertModelCovers(message, "message")
    }

    func testTask() throws {
        let task = try decode(WorkspaceTask.self, "task")

        XCTAssertEqual(task.slug, "fix-login-bug-a3f2c1")
        XCTAssertEqual(task.state, "open")
        XCTAssertEqual(task.priority, "high")
        XCTAssertNil(task.assignee, "the golden task is unassigned")
        XCTAssertNil(task.dueDate)

        try assertModelCovers(task, "task")
    }

    func testDocument() throws {
        let document = try decode(Document.self, "document")

        XCTAssertEqual(document.slug, "getting-started")
        XCTAssertEqual(document.title, "Getting Started")
        XCTAssertTrue(document.published)
        XCTAssertNotNil(document.body, "show responses carry the body")

        try assertModelCovers(document, "document")
    }

    func testDeviceSession() throws {
        let tokens = try decode(AuthTokens.self, "device_session")

        XCTAssertEqual(tokens.tokenType, "Bearer")
        XCTAssertEqual(tokens.device.platform, "android")
        XCTAssertEqual(tokens.workspace.slug, "acme-corp")
        XCTAssertEqual(tokens.user.emailVerified, true)
        XCTAssertFalse(tokens.scopes.isEmpty, "a session without scopes can do nothing")

        // `agent` is non-optional here because a phone session is always
        // agent-bound. A `platform: "cli"` session is not, which is why the Go
        // client models it as a pointer — if iOS ever mints one, this throws.
        XCTAssertEqual(tokens.agent.slug, "golden-device-ba8bc0")

        try assertModelCovers(tokens, "device_session")
    }

    /// The payloads this package cannot decode at all, listed so the gap is a
    /// stated fact rather than an oversight. `member`, `notification`,
    /// `project`, `upload`, `database` and `row` have no Swift model; the Go
    /// and Kotlin clients cover them.
    func testUnmodelledPayloadsAreKnown() {
        let unmodelled = ["database", "member", "notification", "project", "row", "upload"]
        for name in unmodelled {
            XCTAssertNil(
                Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "api_golden"),
                """
                api_golden/\(name).json is checked in but SaltareWorkspace has no model for it. \
                Either add the model and a case above, or drop the file — an unread golden \
                drifts silently.
                """
            )
        }
    }

    // MARK: - Helpers

    private func goldenData(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "api_golden") else {
            throw GoldenError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try decoder.decode(type, from: try goldenData(name))
    }

    /// Asserts every stored property of `value` has a key in the payload, and
    /// prints the payload keys the model has no property for.
    private func assertModelCovers<T>(
        _ value: T,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let object = try JSONSerialization.jsonObject(with: try goldenData(name))
        guard let payload = object as? [String: Any] else {
            XCTFail("\(name).json is not a JSON object", file: file, line: line)
            return
        }

        let keys = Set(payload.keys)
        let declared = Mirror(reflecting: value).children.compactMap { $0.label.map(Self.snakeCased) }

        let missing = declared.filter { !keys.contains($0) }.sorted()
        XCTAssertTrue(
            missing.isEmpty,
            """
            \(name).json has no key for \(missing.joined(separator: ", ")) — the server \
            renamed or dropped it, and \(T.self) now decodes those to nil or throws.
            If the change was intentional, update the model; otherwise the server regressed.
            Resync with script/sync-goldens.sh.
            """,
            file: file,
            line: line
        )

        let ignored = keys.subtracting(declared).sorted()
        if !ignored.isEmpty {
            print("· \(name): server keys \(T.self) ignores — \(ignored.joined(separator: ", "))")
        }
    }

    /// The inverse of `.convertFromSnakeCase`, which is how a property name maps
    /// back to the key it was decoded from.
    private static func snakeCased(_ camelCased: String) -> String {
        var out = ""
        for character in camelCased {
            if character.isUppercase {
                out.append("_")
                out.append(contentsOf: character.lowercased())
            } else {
                out.append(character)
            }
        }
        return out
    }
}
