/// The selectable key grids. `numeric` is never reached by tapping — only by a
/// field that asks for it (see `EditorContext`).
public enum LayoutPage: Equatable, Sendable, CaseIterable {
    case letters
    case symbolsOne
    case symbolsTwo
    case numeric
}
