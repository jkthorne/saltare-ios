import Foundation

/// "5 km to mi" → "3.107 MI". Curated dimensions only; anything it doesn't
/// recognize returns nil so app search wins. Temperature is the affine special
/// case; everything else is a factor to a base unit. Ported 1:1 from the
/// Android `:launcher` `UnitConvert`.
public enum UnitConvert {

    private struct UnitDef: Sendable {
        let dimension: String
        let toBase: @Sendable (Double) -> Double
        let fromBase: @Sendable (Double) -> Double
    }

    private static func linear(_ dimension: String, _ factor: Double) -> UnitDef {
        UnitDef(dimension: dimension, toBase: { $0 * factor }, fromBase: { $0 / factor })
    }

    private static let units: [String: UnitDef] = {
        var m: [String: UnitDef] = [:]
        // length (base: metre)
        m["mm"] = linear("length", 0.001)
        m["cm"] = linear("length", 0.01)
        m["m"] = linear("length", 1.0)
        m["km"] = linear("length", 1000.0)
        m["in"] = linear("length", 0.0254)
        m["ft"] = linear("length", 0.3048)
        m["yd"] = linear("length", 0.9144)
        m["mi"] = linear("length", 1609.344)
        // mass (base: kilogram)
        m["mg"] = linear("mass", 1e-6)
        m["g"] = linear("mass", 0.001)
        m["kg"] = linear("mass", 1.0)
        m["lb"] = linear("mass", 0.45359237)
        m["oz"] = linear("mass", 0.028349523125)
        // data (base: byte, binary multiples)
        m["b"] = linear("data", 1.0)
        m["kb"] = linear("data", 1024.0)
        m["mb"] = linear("data", 1024.0 * 1024)
        m["gb"] = linear("data", 1024.0 * 1024 * 1024)
        m["tb"] = linear("data", 1024.0 * 1024 * 1024 * 1024)
        // temperature (base: celsius) — affine, not a factor
        m["c"] = UnitDef(dimension: "temp", toBase: { $0 }, fromBase: { $0 })
        m["°c"] = UnitDef(dimension: "temp", toBase: { $0 }, fromBase: { $0 })
        m["f"] = UnitDef(dimension: "temp", toBase: { ($0 - 32) * 5 / 9 }, fromBase: { $0 * 9 / 5 + 32 })
        m["°f"] = UnitDef(dimension: "temp", toBase: { ($0 - 32) * 5 / 9 }, fromBase: { $0 * 9 / 5 + 32 })
        m["k"] = UnitDef(dimension: "temp", toBase: { $0 - 273.15 }, fromBase: { $0 + 273.15 })
        return m
    }()

    private static let pattern = try! NSRegularExpression(
        pattern: #"^\s*(-?\d+(?:[.,]\d+)?)\s*([a-zA-Z°]+)\s+to\s+([a-zA-Z°]+)\s*$"#,
        options: [.caseInsensitive]
    )

    /// Pre-formatted "value UNIT", or nil when the query isn't a conversion.
    public static func convert(_ query: String) -> String? {
        let range = NSRange(query.startIndex..<query.endIndex, in: query)
        guard let match = pattern.firstMatch(in: query, options: [], range: range),
              match.numberOfRanges == 4 else { return nil }

        func group(_ i: Int) -> String {
            guard let r = Range(match.range(at: i), in: query) else { return "" }
            return String(query[r])
        }

        guard let value = Double(group(1).replacingOccurrences(of: ",", with: ".")) else { return nil }
        let fromName = group(2)
        let toName = group(3)
        guard let from = units[fromName.lowercased()], let to = units[toName.lowercased()] else { return nil }
        guard from.dimension == to.dimension else { return nil }
        let converted = to.fromBase(from.toBase(value))
        guard converted.isFinite else { return nil }
        return "\(format(converted)) \(toName.uppercased())"
    }

    /// Four significant digits, trailing zeros stripped, whole numbers bare.
    private static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value == value.rounded() && abs(value) < 1e15 { return String(Int64(value)) }
        return String(format: "%.4g", value)
    }
}
