import SwiftUI

/// `input-field` — carbon surface, hairline border that shifts chrome → arc on
/// focus → phoenix on error. Mono uppercase label above, hint/error line below.
public struct HudTextField: View {
    let label: String?
    let placeholder: String
    let hint: String?
    let errorMessage: String?
    @Binding var text: String

    @FocusState private var focused: Bool
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(
        text: Binding<String>,
        label: String? = nil,
        placeholder: String = "",
        hint: String? = nil,
        errorMessage: String? = nil
    ) {
        self._text = text
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.errorMessage = errorMessage
    }

    private var isError: Bool { errorMessage != nil }

    public var body: some View {
        let border: Color = isError ? colors.phoenix : (focused ? colors.arc : colors.chrome)

        VStack(alignment: .leading, spacing: 6) {
            if let label {
                HudText(label.uppercased(), color: colors.mist, style: typography.hudLabel)
            }
            ZStack(alignment: .leading) {
                if text.isEmpty && !placeholder.isEmpty {
                    HudText(placeholder, color: colors.silver, style: typography.body)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(typography.body.font)
                    .foregroundStyle(colors.frost)
                    .tint(colors.arc)
                    .focused($focused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.carbon)
            .overlay(Rectangle().strokeBorder(border, lineWidth: 1))

            if let errorMessage {
                HudText(errorMessage, color: colors.phoenix, style: typography.monoBody)
            } else if let hint {
                HudText(hint, color: colors.silver, style: typography.monoBody)
            }
        }
    }
}
