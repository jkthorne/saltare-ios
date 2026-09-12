import XCTest
@testable import SaltareWorkspace

final class ActionCableProtocolTests: XCTestCase {

    // MARK: - Identifier

    func testIdentifierEncodingIsDeterministicChannelFirstThenSortedParams() {
        let id = CableIdentifier(channel: "MessagesChannel", params: ["channel_id": .int(42), "since": .string("z")])
        XCTAssertEqual(id.encoded, #"{"channel":"MessagesChannel","channel_id":42,"since":"z"}"#)
        XCTAssertEqual(CableIdentifier.messages(channelId: 42).encoded, #"{"channel":"MessagesChannel","channel_id":42}"#)
    }

    func testIdentifierRoundTrips() {
        let id = CableIdentifier.messages(channelId: 7)
        XCTAssertEqual(CableIdentifier.decode(id.encoded), id)
    }

    func testIdentifierDecodeIgnoresUnknownValueShapes() {
        let decoded = CableIdentifier.decode(#"{"channel":"X","channel_id":3,"nested":{"a":1}}"#)
        XCTAssertEqual(decoded, CableIdentifier(channel: "X", params: ["channel_id": .int(3)]))
    }

    // MARK: - Outbound commands

    func testEncodeSubscribeNestsTheIdentifierString() throws {
        let data = ActionCableProtocol.encode(.subscribe(.messages(channelId: 42)))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["command"] as? String, "subscribe")
        XCTAssertEqual(object["identifier"] as? String, #"{"channel":"MessagesChannel","channel_id":42}"#)
    }

    func testEncodeMessageWrapsActionPayloadAsAJSONString() throws {
        let data = ActionCableProtocol.encode(
            .message(.messages(channelId: 9), action: "speak", payload: ["body": .string("hi")])
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["command"] as? String, "message")
        let inner = try XCTUnwrap(object["data"] as? String)
        let innerObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(inner.utf8)) as? [String: Any])
        XCTAssertEqual(innerObject["action"] as? String, "speak")
        XCTAssertEqual(innerObject["body"] as? String, "hi")
    }

    // MARK: - Inbound frames

    func testDecodeControlFrames() {
        XCTAssertEqual(ActionCableProtocol.decode(Data(#"{"type":"welcome"}"#.utf8)), .welcome)
        XCTAssertEqual(ActionCableProtocol.decode(Data(#"{"type":"ping","message":1700000000}"#.utf8)), .ping(1700000000))
        XCTAssertEqual(
            ActionCableProtocol.decode(Data(#"{"type":"confirm_subscription","identifier":"{\"channel\":\"MessagesChannel\",\"channel_id\":5}"}"#.utf8)),
            .confirmed(.messages(channelId: 5))
        )
        XCTAssertEqual(
            ActionCableProtocol.decode(Data(#"{"type":"disconnect","reason":"unauthorized","reconnect":false}"#.utf8)),
            .disconnect(reason: "unauthorized", reconnect: false)
        )
    }

    func testDecodeDataFrameSurfacesIdentifierAndRawPayload() throws {
        let frame = #"{"identifier":"{\"channel\":\"MessagesChannel\",\"channel_id\":5}","message":{"event":"message_created","data":{"id":11,"channel_id":5,"sender":{"type":"User","id":2},"body":"yo","created_at":"2026-06-15T00:00:00Z","updated_at":"2026-06-15T00:00:00Z"}}}"#
        guard case let .message(identifier, payload) = ActionCableProtocol.decode(Data(frame.utf8)) else {
            return XCTFail("expected a message event")
        }
        XCTAssertEqual(identifier, .messages(channelId: 5))

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let event = try decoder.decode(ChannelMessageEvent.self, from: payload)
        XCTAssertEqual(event.event, "message_created")
        XCTAssertEqual(event.data.id, 11)
        XCTAssertEqual(event.data.body, "yo")
    }

    func testDecodeGarbageIsUnknown() {
        XCTAssertEqual(ActionCableProtocol.decode(Data("not json".utf8)), .unknown)
        XCTAssertEqual(ActionCableProtocol.decode(Data(#"{"type":"mystery"}"#.utf8)), .unknown)
    }

    // MARK: - Cable URL

    func testCableURLDerivation() {
        XCTAssertEqual(RealtimeClient.cableURL(from: URL(string: "https://saltare.ai")!).absoluteString, "wss://saltare.ai/cable")
        XCTAssertEqual(RealtimeClient.cableURL(from: URL(string: "http://localhost:3000")!).absoluteString, "ws://localhost:3000/cable")
    }

    // MARK: - Handshake

    func testHandshakeCarriesTheTokenInTheHeaderAndNotTheURL() {
        let url = RealtimeClient.cableURL(from: URL(string: "https://saltare.ai")!)
        let request = RealtimeClient.handshakeRequest(url: url, token: "sk_sal_secret")

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk_sal_secret")
        XCTAssertEqual(request.url?.absoluteString, "wss://saltare.ai/cable")
        XCTAssertFalse(request.url?.absoluteString.contains("sk_sal_secret") ?? true,
                       "a bearer token in the URL ends up in every access log on the way")
    }

    func testHandshakeWithoutATokenSendsNoAuthorization() {
        let url = RealtimeClient.cableURL(from: URL(string: "https://saltare.ai")!)
        XCTAssertNil(RealtimeClient.handshakeRequest(url: url, token: nil).value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(RealtimeClient.handshakeRequest(url: url, token: "").value(forHTTPHeaderField: "Authorization"))
    }
}
