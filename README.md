# saltare-ios

A native SwiftUI app for [saltare](https://saltare.ai) — the iOS counterpart to
[saltareOS](../saltareos) (the Android take). Same NieR:Automata-inspired HUD,
the same universal-input + on-device-Claude-agent thesis, deeply integrated with
the `saltare` Rails workspace through MCP and the REST API.

> Not the Hotwire Native webview shell in `saltare/mobile/ios` — this is a
> genuinely native app that ports the saltareOS concepts and reaches across the
> iOS surfaces Android doesn't have (App Intents/Siri, Spotlight, Widgets,
> Controls, Live Activities, Share extension).

**Status & direction: see [ROADMAP.md](ROADMAP.md).** iP0 (the `SaltareHUD`
design system) is done; iP1 (the universal-input command surface) is next.

## Packages

| Package | What |
|---|---|
| `Packages/SaltareHUD` | The design system as a **foundation-only SwiftUI package** — no UIKit chrome. Tokens ported 1:1 from saltare's `application.css` (dark "android" + light "parchment"), Geist/Geist Mono, corner brackets, diamond markers, scan bars, HUD components. Includes a `ShowcaseView` gallery. |
| `Packages/SaltareKit` | The **pure-Swift domain** (no UIKit/SwiftUI) — the universal-input search engine: `AppSearch` ranking, `Calculator`, `UnitConvert`, `Frecency`, the `SearchResult` contract. Ported 1:1 from the Android `:launcher` `domain/` with its test suites (59 tests). |

(Future: `SaltareAgent`, the `Saltare` app target, and the keyboard/widget/
share/intents extensions — see the roadmap.)

## Build & test

```bash
cd Packages/SaltareHUD
swift build
swift test
```

Requires Xcode 26 / Swift 6.3. The package targets iOS 17+ and macOS 14+ (so the
design system builds and tests on the Mac without a simulator). The app target
will require iOS 18+.

Open `Packages/SaltareHUD/Package.swift` in Xcode and use the `ShowcaseView`
SwiftUI previews (Dark + Parchment) to see the system.

## Design source of truth

The web design system at `saltare/app/assets/tailwind/application.css`. Porting
rule: CSS `#RRGGBBAA` → `Color(argb: 0xAARRGGBB)` (the alpha byte moves to the
front) — enforced by exhaustive token tests in `SaltareHUDTests`.

## License notes

Geist & Geist Mono are bundled under the SIL OFL 1.1
(`Packages/SaltareHUD/Sources/SaltareHUD/Resources/Fonts/OFL-Geist.txt`).
See `NOTICE`.
