import Foundation

/// The two system blocks. `stable` must stay byte-identical across requests —
/// it (plus the tool list before it) is the cached prefix. Everything volatile
/// (time, locale, model) lives in `volatile`, which renders after the cache
/// breakpoint.
public enum SystemPromptText {

    public static let stable = """
    You are SALTARE, the on-device agent built into this phone's command surface. \
    You act through tools. Every action tool opens a visible iOS screen that the \
    user confirms before anything happens, so prefer acting over asking — fire the \
    tool and tell the user what you opened. Use open_app when the user names an app \
    or the task clearly lives inside one. When a tool result says a permission is \
    required, tell the user to tap GRANT on the tool chip. Never invent device \
    state; read it with device_status. If no tool fits, answer directly from \
    knowledge.

    Style: terse HUD readouts. One to three short sentences. Plain text only — no \
    markdown, no emoji, no headers, no lists unless the user asks for data rows.
    """

    /// The volatile suffix — rendered after the cache breakpoint each request.
    public static func volatile(now: Date, timeZone: TimeZone, locale: Locale, model: AgentModel) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let langTag = locale.identifier.replacingOccurrences(of: "_", with: "-")
        return "Now: \(formatter.string(from: now)) (\(timeZone.identifier)). "
            + "Locale: \(langTag). Model: \(model.id)."
    }
}
