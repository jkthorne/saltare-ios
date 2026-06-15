import Foundation

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognized JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case let .bool(b): try c.encode(b)
        case let .number(n): try c.encode(n)
        case let .string(s): try c.encode(s)
        case let .array(a): try c.encode(a)
        case let .object(o): try c.encode(o)
        }
    }
}

public extension JSONValue {
    var intValue: Int? { if case let .number(n) = self { return Int(n) }; return nil }

    /// Object-member access (`nil` for non-objects / missing keys).
    subscript(_ key: String) -> JSONValue? { objectValue?[key] }

    func serializedData() throws -> Data { try JSONEncoder().encode(self) }

    static func parse(_ data: Data) -> JSONValue? { try? JSONDecoder().decode(JSONValue.self, from: data) }

    static func parse(_ string: String) -> JSONValue? { parse(Data(string.utf8)) }
}
