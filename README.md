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
**iP2 (the on-device Claude agent) is underway:** iP2.1 — the pure agent core
(`SaltareAgent`: the manual tool loop + domain, ported 1:1 from the Android
`:agent`, 14 tests) — is done. Next: the Anthropic `URLSession` SSE client +
Keychain key (iP2.2).

## Packages

| Package | What |
|---|---|
| `Packages/SaltareHUD` | The design system as a **foundation-only SwiftUI package** — no UIKit chrome. Tokens ported 1:1 from saltare's `application.css` (dark "android" + light "parchment"), Geist/Geist Mono, corner brackets, diamond markers, scan bars, HUD components. Includes a `ShowcaseView` gallery. |
| `Packages/SaltareKit` | The **pure-Swift domain** (no UIKit/SwiftUI) — the universal-input search engine: `AppSearch` ranking, `Calculator`, `UnitConvert`, `Frecency`, the `SearchResult` contract. Ported 1:1 from the Android `:launcher` `domain/` with its test suites (63 tests). |
| `Packages/SaltareAgent` | The **pure-Swift agent core** (no UIKit/SDK/network) — the manual streaming tool loop (`AgentLoop`) + domain (`AgentModel`, `ToolSpec`, `LlmClient`, `AgentHistory`, `SystemPromptText`). Ported 1:1 from the Android `:agent` `domain/` + `loop/` with its `AgentLoopTest` suite (14 tests). |

(Future: `SaltareAgent`, the `Saltare` app target, and the keyboard/widget/
share/intents extensions — see the roadmap.)

## Build & test

The pure packages build and test on the Mac without a simulator:

```bash
( cd Packages/SaltareHUD && swift build && swift test )   # design system — 8 tests
( cd Packages/SaltareKit && swift build && swift test )   # search engine — 59 tests
```

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
