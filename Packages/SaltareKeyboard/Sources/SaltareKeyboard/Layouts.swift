/// The static key grids, English only. Pure data, so the layouts are testable
/// (row counts, no duplicate characters, every page can get home) without a
/// running keyboard.
public enum Layouts {

    /// The rows of `page`. `globe` inserts the next-keyboard key into the bottom
    /// row — iOS asks for it only while other keyboards are installed
    /// (`needsInputModeSwitchKey`), and drawing it unconditionally would strand
    /// a dead key on a device that has only this one.
    public static func rows(_ page: LayoutPage, globe: Bool = false) -> [[Key]] {
        let rows: [[Key]]
        switch page {
        case .letters: rows = letters
        case .symbolsOne: rows = symbolsOne
        case .symbolsTwo: rows = symbolsTwo
        case .numeric: rows = numeric
        }
        guard globe else { return rows }
        var withGlobe = rows
        withGlobe[withGlobe.count - 1].insert(.globe, at: bottomRowGlobeIndex(page))
        return withGlobe
    }

    /// After the page-switch key where there is one, so the globe sits in the
    /// same corner the system keyboard puts it in.
    private static func bottomRowGlobeIndex(_ page: LayoutPage) -> Int {
        page == .numeric ? 0 : 1
    }

    private static func chars(_ s: String) -> [Key] { s.map { Key.char($0) } }

    // The top row carries the digits as long-press alternates, like AOSP.
    private static let letterTop: [Key] = {
        let letters = Array("qwertyuiop")
        let digits = Array("1234567890")
        var keys: [Key] = []
        for i in letters.indices {
            keys.append(.char(letters[i], alternates: String(digits[i])))
        }
        return keys
    }()

    private static let letters: [[Key]] = [
        letterTop,
        chars("asdfghjkl"),
        [.shift] + chars("zxcvbnm") + [.backspace],
        [
            .page(.symbolsOne, label: "?123"),
            .char(",", alternates: "!"),
            .space,
            .char(".", alternates: "?"),
            .enter,
        ],
    ]

    private static let symbolsOne: [[Key]] = [
        chars("1234567890"),
        chars("@#$_&-+()/"),
        [.page(.symbolsTwo, label: "=\\<")] + chars("*\"':;!?") + [.backspace],
        [
            .page(.letters, label: "ABC"),
            .char(","),
            .space,
            .char("."),
            .enter,
        ],
    ]

    private static let symbolsTwo: [[Key]] = [
        chars("~`|•√π÷×¶∆"),
        chars("£¢€¥^°={}\\"),
        [.page(.symbolsOne, label: "?123")] + chars("©®™%[]<>") + [.backspace],
        [
            .page(.letters, label: "ABC"),
            .char(","),
            .space,
            .char("."),
            .enter,
        ],
    ]

    private static let numeric: [[Key]] = [
        chars("123"),
        chars("456"),
        chars("789"),
        [.char("."), .char("0"), .backspace],
    ]
}
