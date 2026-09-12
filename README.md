# saltare-ios

A native SwiftUI app for [saltare](https://saltare.ai) — the iOS counterpart to
[saltareOS](../saltareos) (the Android take). Same NieR:Automata-inspired HUD,
the same universal-input + on-device-Claude-agent thesis, deeply integrated with
the `saltare` Rails workspace through MCP and the REST API.

> Not the Hotwire Native webview shell in `saltare/mobile/ios` — this is a
> genuinely native app that ports the saltareOS concepts and reaches across the
> iOS surfaces Android doesn't have (App Intents/Siri, Spotlight, Widgets,
> Controls, Live Activities, Share extension).

**Status & direction: see [ROADMAP.md](ROADMAP.md).** **iP1 is complete** — the
universal-input command surface: `SaltareHUD` design system, `SaltareKit`
engine, the app target, wired row actions (launch/frecency, Contacts, copy), and
system reach (App Intents/Spotlight/Siri, a Widget + iOS Control, deep links,
haptics, VoiceOver). The app + widget extension build and run on the simulator.
**iP2 is complete — the on-device Claude agent.** Manual streaming tool loop
(`AgentLoop`), the Anthropic Messages API client (`URLSession` SSE + Keychain key
vault), the iOS toolbox (registry/executor + intent/`device_status`/GRANT-gated
Contacts & Calendar tools, `open_app`), and the HUD agent sheet (streaming
transcript, tool chips, permission GRANT, model picker) wired to the AgentStub
row, plus the agent's **MCP `saltare__*` workspace tools** (iP3.4).
`SaltareAgent` is **45 tests**; the app builds and the sheet renders
on the simulator.

**iP3 (deep `saltare` integration) is underway:** iP3.1 (pure REST client, 12
tests), iP3.2 (native **sign-in** + Keychain **token vault** + the agent on the
**inference proxy** — no on-device Anthropic key), iP3.3 (the **workspace
browser** — HUD Chat/Tasks/Agents/Docs over the REST client, with a channel
thread + composer), and iP3.4 (the agent's **MCP `saltare__*` tools** — an
`McpClient` over the Streamable-HTTP `/mcp` endpoint, appended after the device
tools, so the on-device agent can act on the workspace), and iP3.5 (the **Action
Cable** realtime client — `RealtimeClient` over a `URLSession` websocket, so a
channel thread streams live messages and shows a **LIVE** chip) are done; the app
builds, the browser renders, and the agent sheet shows the connected-tool count.
Realtime's two server prerequisites (bearer-token auth on the cable + a JSON
`MessagesChannel`) are now **closed server-side** in the `saltare` repo, so it's
end-to-end capable. iP3.6 (the first **system-reach** cut — **CoreSpotlight**
indexing of workspace tasks/docs, deep-linking back into the workspace browser)
is done, iP3.7 adds a **Live Activity** for a running agent turn (Lock Screen +
Dynamic Island), iP3.8 adds a **workspace Widget** (recent channels/tasks via a
shared App Group snapshot), and iP3.9 adds a **Share extension** (send shared
text/URL to a channel or create a task, via the shared-Keychain token) — which
completes iP3. Next: iP4 (the `SaltareKeyboard` extension).

## Packages

| Package | What |
|---|---|
| `Packages/SaltareHUD` | The design system as a **foundation-only SwiftUI package** — no UIKit chrome. Tokens ported 1:1 from saltare's `application.css` (dark "android" + light "parchment"), Geist/Geist Mono, corner brackets, diamond markers, scan bars, HUD components. Includes a `ShowcaseView` gallery. |
| `Packages/SaltareKit` | The **pure-Swift domain** (no UIKit/SwiftUI) — the universal-input search engine: `AppSearch` ranking, `Calculator`, `UnitConvert`, `Frecency`, the `SearchResult` contract. Ported 1:1 from the Android `:launcher` `domain/` with its test suites (63 tests). |
| `Packages/SaltareAgent` | The **agent core + Anthropic boundary** (Foundation-only, no UIKit/SDK) — the manual streaming tool loop (`AgentLoop`) + domain, the Messages API layer (`AnthropicRequest`, `AnthropicSSEParser`, `AnthropicLlmClient` over `URLSession.bytes`), the tool registry/executor, the `TranscriptReducer`, the **MCP client** (`McpClient`/`McpToolSource` — `saltare__*` workspace tools over the Streamable-HTTP `/mcp` endpoint), and the Live Activity presentation (`AgentActivityPresentation`). Ported from the Android `:agent` with its test suites (45 tests). |
| `Packages/SaltareWorkspace` | The **saltare REST + realtime client** (Foundation-only) — `Decodable` models ported from the `Api::V1::*Serializer`s, pure `WorkspaceEndpoint` builders, the `URLSession` `WorkspaceClient` (Bearer auth, `{data:…}` unwrap, `{error}` envelope), native device auth (`POST /api/v1/auth/token`), the **Action Cable** client (`ActionCableProtocol` wire codec + `RealtimeClient` websocket transport), the **Spotlight** mapping (`SpotlightEntry`/`SpotlightIndex`), the **widget snapshot** (`WorkspaceSnapshot`), and the **share draft** parser (`ShareDraft`), plus `WorkspaceEnvironment` (the overridable base URL). 55 tests. |

(The `Saltare` app target and the widget / share / intents extensions live at
the repo root, outside `Packages/`. `SaltareKeyboard` is still to come — see the
roadmap.)

## Build & test

The pure packages build and test on the Mac without a simulator:

```bash
( cd Packages/SaltareHUD && swift build && swift test )        # design system — 8 tests
( cd Packages/SaltareKit && swift build && swift test )        # search engine — 63 tests
( cd Packages/SaltareAgent && swift build && swift test )      # agent + Anthropic — 45 tests
( cd Packages/SaltareWorkspace && swift build && swift test )  # saltare client — 55 tests
```

CI (`.github/workflows/ci.yml`) runs all four on every push and pull request,
then builds the app and its two embedded extensions with XcodeGen + xcodebuild.

The app target is generated from `project.yml` by **XcodeGen** (the `.xcodeproj`
is gitignored — regenerate it, never commit it):

```bash
brew install xcodegen          # once
xcodegen generate              # writes Saltare.xcodeproj
open Saltare.xcodeproj          # ⌘R to run on a simulator
# or headless:
xcodebuild -project Saltare.xcodeproj -scheme Saltare -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Requires Xcode 26 / Swift 6.3. The packages target iOS 17+/macOS 13–14; the app
requires iOS 18+. Use the `ShowcaseView` previews (Dark + Parchment) in
`SaltareHUD` to browse the design system.

## Design source of truth

The web design system at `saltare/app/assets/tailwind/application.css`. Porting
rule: CSS `#RRGGBBAA` → `Color(argb: 0xAARRGGBB)` (the alpha byte moves to the
front) — enforced by exhaustive token tests in `SaltareHUDTests`.

## License notes

Geist & Geist Mono are bundled under the SIL OFL 1.1
(`Packages/SaltareHUD/Sources/SaltareHUD/Resources/Fonts/OFL-Geist.txt`).
See `NOTICE`.
