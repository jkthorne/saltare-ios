import Foundation

/// Minimal shunting-yard arithmetic for the universal input. Returns nil for
/// anything that isn't unambiguously math: a query with no operator (so "2048"
/// finds the app, not the number), foreign characters, or a non-finite result
/// (division by zero, overflow) — nil means "no calculator row", never an error
/// shown to the user.
///
/// Ported 1:1 from the Android `:launcher` `Calculator`.
public enum Calculator {

    private static let unaryMinus: Character = "u"

    private enum Token: Equatable {
        case num(Double)
        case op(Character)
        case lParen
        case rParen
    }

    /// Pre-formatted result ("= …" prefix is the UI's job), or nil.
    public static func evaluate(_ expression: String) -> String? {
        guard let tokens = tokenize(expression) else { return nil }
        let hasRealOp = tokens.contains {
            if case let .op(sym) = $0 { return sym != unaryMinus }
            return false
        }
        guard hasRealOp else { return nil }
        guard let rpn = toRpn(tokens), let value = evalRpn(rpn), value.isFinite else { return nil }
        return format(value)
    }

    private static func precedence(_ op: Character) -> Int {
        switch op {
        case "+", "-": return 1
        case "*", "/", "%": return 2
        case unaryMinus: return 3
        case "^": return 4
        default: return 0
        }
    }

    private static func rightAssociative(_ op: Character) -> Bool { op == "^" || op == unaryMinus }

    private static func tokenize(_ expression: String) -> [Token]? {
        var tokens: [Token] = []
        let s = Array(expression.trimmingCharacters(in: .whitespaces))
        if s.isEmpty { return nil }
        var i = 0
        while i < s.count {
            let c = s[i]
            switch true {
            case c == " ":
                i += 1
            case c.isNumber || c == "." || c == ",":
                let start = i
                while i < s.count && (s[i].isNumber || s[i] == "." || s[i] == ",") { i += 1 }
                // Comma is a decimal separator ("3,5" == 3.5); >1 separator is
                // not a number we understand.
                let raw = String(s[start..<i]).replacingOccurrences(of: ",", with: ".")
                if raw.filter({ $0 == "." }).count > 1 { return nil }
                guard let value = Double(raw) else { return nil }
                tokens.append(.num(value))
            case c == "(":
                tokens.append(.lParen); i += 1
            case c == ")":
                tokens.append(.rParen); i += 1
            case "+-*/%^".contains(c):
                let prevIsOpenContext: Bool = {
                    guard let last = tokens.last else { return true }
                    if case .op = last { return true }
                    if case .lParen = last { return true }
                    return false
                }()
                let unary = c == "-" && prevIsOpenContext
                tokens.append(.op(unary ? unaryMinus : c))
                i += 1
            default:
                return nil
            }
        }
        return tokens
    }

    private static func toRpn(_ tokens: [Token]) -> [Token]? {
        var out: [Token] = []
        var ops: [Token] = []
        for t in tokens {
            switch t {
            case .num:
                out.append(t)
            case let .op(sym):
                while let top = ops.last, case let .op(topSym) = top {
                    let pops = precedence(topSym) > precedence(sym) ||
                        (precedence(topSym) == precedence(sym) && !rightAssociative(sym))
                    if !pops { break }
                    out.append(ops.removeLast())
                }
                ops.append(t)
            case .lParen:
                ops.append(t)
            case .rParen:
                while let top = ops.last, top != .lParen { out.append(ops.removeLast()) }
                if ops.isEmpty { return nil } // unbalanced
                ops.removeLast() // pop the lParen
            }
        }
        while let op = ops.popLast() {
            if op == .lParen { return nil } // unbalanced
            out.append(op)
        }
        return out
    }

    private static func evalRpn(_ rpn: [Token]) -> Double? {
        var stack: [Double] = []
        for t in rpn {
            switch t {
            case let .num(v):
                stack.append(v)
            case let .op(sym):
                if sym == unaryMinus {
                    guard let a = stack.popLast() else { return nil }
                    stack.append(-a)
                } else {
                    guard let b = stack.popLast(), let a = stack.popLast() else { return nil }
                    switch sym {
                    case "+": stack.append(a + b)
                    case "-": stack.append(a - b)
                    case "*": stack.append(a * b)
                    case "/": stack.append(a / b)
                    case "%": stack.append(a.truncatingRemainder(dividingBy: b))
                    case "^": stack.append(pow(a, b))
                    default: return nil
                    }
                }
            default:
                return nil
            }
        }
        return stack.count == 1 ? stack[0] : nil
    }

    /// Whole numbers render bare ("6", never "6.0"); the rest cap at 10
    /// significant digits with trailing zeros stripped.
    static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value == value.rounded() && abs(value) < 1e15 { return String(Int64(value)) }
        return String(format: "%.10g", value)
    }
}
