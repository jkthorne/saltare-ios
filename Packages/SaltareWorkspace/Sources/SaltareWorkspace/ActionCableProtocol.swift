import Foundation

/// A scalar in an Action Cable subscription identifier or action payload.
/// saltare channels key on integer ids (`channel_id`); strings cover names/uuids.
public enum CableValue: Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)

    var jsonObject: Any {
        switch self {
        case let .string(s): return s
        case let .int(i): return i
        }
    }

    init?(_ any: Any) {
        switch any {
        case let s as String: self = .string(s)
        // JSONSerialization yields NSNumber; Int(exactly:) keeps integers integral.
        case let n as NSNumber: self = .int(n.intValue)
        default: return nil
        }
    }
}

/// An Action Cable channel subscription identifier — `{channel: …, …params}`,
/// JSON-encoded to the canonical string the protocol uses as the subscription
/// key. Keys are emitted with `channel` first then params sorted, so the encoded
/// string is deterministic (tests + identifier matching depend on it).
public struct CableIdentifier: Sendable, Equatable, Hashable {
    public let channel: String
    public let params: [String: CableValue]

    public init(channel: String, params: [String: CableValue] = [:]) {
        self.channel = channel
        self.params = params
    }

    /// `MessagesChannel` keyed by a channel id — the live message stream.
    public static func messages(channelId: Int) -> CableIdentifier {
        CableIdentifier(channel: "MessagesChannel", params: ["channel_id": .int(channelId)])
    }

    public var encoded: String {
        var parts = ["\"channel\":\(Self.jsonString(channel))"]
        for key in params.keys.sorted() {
            parts.append("\(Self.jsonString(key)):\(Self.scalar(params[key]!))")
        }
        return "{\(parts.joined(separator: ","))}"
    }

    /// Parse an identifier string the server echoed back (`confirm_subscription`,
    /// data frames). Lenient — unknown value types are dropped.
    public static func decode(_ encoded: String) -> CableIdentifier? {
        guard let object = (try? JSONSerialization.jsonObject(with: Data(encoded.utf8))) as? [String: Any],
              let channel = object["channel"] as? String else { return nil }
        var params: [String: CableValue] = [:]
        for (key, value) in object where key != "channel" {
            if let scalar = CableValue(value) { params[key] = scalar }
        }
        return CableIdentifier(channel: channel, params: params)
    }

    private static func scalar(_ value: CableValue) -> String {
        switch value {
        case let .string(s): return jsonString(s)
        case let .int(i): return String(i)
        }
    }

    /// JSON-escaped, quoted string (handles the characters Action Cable channel
    /// names + ids can realistically contain).
    private static func jsonString(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [s], options: [])
        guard let data, let array = String(data: data, encoding: .utf8) else { return "\"\(s)\"" }
        // `["x"]` → `"x"`
        return String(array.dropFirst().dropLast())
    }
}

/// A command the client sends up the socket.
public enum CableCommand: Sendable, Equatable {
    case subscribe(CableIdentifier)
    case unsubscribe(CableIdentifier)
    /// `perform` an action on a subscribed channel.
    case message(CableIdentifier, action: String, payload: [String: CableValue])
}

/// A frame the server sends down the socket.
public enum CableEvent: Sendable, Equatable {
    case welcome
    case ping(Int?)
    case confirmed(CableIdentifier)
    case rejected(CableIdentifier)
    case disconnect(reason: String?, reconnect: Bool)
    /// A channel broadcast. `payload` is the raw JSON of the `message` member,
    /// re-serialized for the consumer to decode into a typed model.
    case message(identifier: CableIdentifier, payload: Data)
    case unknown
}

/// Pure (de)serialization of the Action Cable wire protocol — no sockets, fully
/// testable. The transport (`RealtimeClient`) is the thin glue around it.
public enum ActionCableProtocol {
    public static func encode(_ command: CableCommand) -> Data {
        let object: [String: Any]
        switch command {
        case let .subscribe(id):
            object = ["command": "subscribe", "identifier": id.encoded]
        case let .unsubscribe(id):
            object = ["command": "unsubscribe", "identifier": id.encoded]
        case let .message(id, action, payload):
            var data: [String: Any] = ["action": action]
            for (key, value) in payload { data[key] = value.jsonObject }
            let dataString = (try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            object = ["command": "message", "identifier": id.encoded, "data": dataString]
        }
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
    }

    public static func decode(_ data: Data) -> CableEvent {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .unknown }

        if let type = object["type"] as? String {
            switch type {
            case "welcome": return .welcome
            case "ping": return .ping((object["message"] as? NSNumber)?.intValue)
            case "confirm_subscription":
                return (object["identifier"] as? String).flatMap(CableIdentifier.decode).map(CableEvent.confirmed) ?? .unknown
            case "reject_subscription":
                return (object["identifier"] as? String).flatMap(CableIdentifier.decode).map(CableEvent.rejected) ?? .unknown
            case "disconnect":
                return .disconnect(reason: object["reason"] as? String, reconnect: (object["reconnect"] as? Bool) ?? false)
            default:
                return .unknown
            }
        }

        // A data frame: `{ identifier, message }`.
        if let identifierString = object["identifier"] as? String,
           let identifier = CableIdentifier.decode(identifierString),
           let message = object["message"] {
            let payload = (try? JSONSerialization.data(withJSONObject: message)) ?? Data()
            return .message(identifier: identifier, payload: payload)
        }
        return .unknown
    }
}
