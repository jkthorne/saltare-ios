import SwiftUI

public enum ReadoutSize: Sendable { case lg, sm }
public enum ReadoutTone: Sendable { case `default`, danger, zero }

/// `nier-readout` — a large monospaced data numeral with an optional small
/// tracked label beneath. `zero` tone dims the value (a zero count is ambient,
/// not information).
public struct NierReadout: View {
    let value: String
    let label: String?
    let size: ReadoutSize
    let tone: ReadoutTone

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(value: String, label: String? = nil, size: ReadoutSize = .lg, tone: ReadoutTone = .default) {
        self.value = value
        self.label = label
        self.size = size
        self.tone = tone
    }

    public var body: some View {
        let valueColor: Color = {
            switch tone {
            case .default: colors.white
            case .danger: colors.phoenix
            case .zero: colors.chrome
            }
        }()
        VStack(alignment: .leading, spacing: 4) {
            HudText(value, color: valueColor, style: size == .lg ? typography.readout : typography.readoutSmall)
            if let label {
                HudText(label.uppercased(), color: colors.silver, style: typography.hudLabelSmall)
            }
        }
    }
}

/// `nier-timestamp` — mono 10 silver time label.
public struct NierTimestamp: View {
    let text: String
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(_ text: String) { self.text = text }

    public var body: some View {
        HudText(text, color: colors.silver, style: typography.timestamp)
    }
}
