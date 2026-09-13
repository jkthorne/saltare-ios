import Foundation

/// QWERTY physical adjacency, used to bias corrections toward fat-finger
/// substitutions (`s` → `a`/`d`) rather than arbitrary letter swaps. Pure data
/// derived from the staggered key grid.
public enum KeyProximity {

    public static func neighbors(of character: Character) -> Set<Character> {
        table[character] ?? []
    }

    private static let table: [Character: Set<Character>] = build()

    private static func build() -> [Character: Set<Character>] {
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        var positions: [Character: (x: Double, y: Double)] = [:]
        for (r, row) in rows.enumerated() {
            for (c, character) in row.enumerated() {
                // Each row is offset half a key to the right of the one above —
                // that stagger is what makes `s` a neighbour of `w` and `e`.
                positions[character] = (Double(c) + Double(r) * 0.5, Double(r))
            }
        }
        var table: [Character: Set<Character>] = [:]
        for (a, pa) in positions {
            for (b, pb) in positions where a != b {
                let dx = pa.x - pb.x
                let dy = pa.y - pb.y
                if abs(dx) <= 1.0, abs(dy) <= 1.0, dx * dx + dy * dy <= 1.3 {
                    table[a, default: []].insert(b)
                }
            }
        }
        return table
    }
}
