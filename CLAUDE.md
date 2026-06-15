# CLAUDE.md

Guidance for Claude Code in the `saltare-ios` repo — the native SwiftUI
counterpart to `~/Developer/saltareos` (Android) and `~/Developer/saltare`
(the Rails workspace).

## What this is

A genuinely native iOS app that ports the saltareOS concepts (HUD design
system, universal-input command surface, on-device Claude agent, NieR keyboard)
and integrates deeply with the `saltare` server via MCP + `/api/v1`.
**Read ROADMAP.md first** for what's done and what's next. The existing
`saltare/mobile/ios` is a *Hotwire Native webview shell* — this repo is the
opposite (native UI).

## Design system rules (`SaltareHUD`)

- **Foundation-only SwiftUI** — no UIKit chrome, no system control styling. We
  own the press/focus indication (`HudIndicationStyle`), text (`HudText` reads
  ambient `hudContentColor`/`hudTextStyle` from the environment — the
  `LocalContentColor`/`LocalTextStyle` analogs), and corner brackets.
- **Source of truth: `../saltare/app/assets/tailwind/application.css`** (same as
  Android `:hud`). CSS `#RRGGBBAA` → `Color(argb: 0xAARRGGBB)` — the alpha byte
  moves to the front. Every token is asserted in `SaltareColorsTests`; update
  both together. The Android `SaltareColors.kt` is the parallel port — keep the
  three in sync.
- Light theme ("parchment") is a full hand-written palette, NOT derived from
  dark (`arcBright` inverts *darker*; glow alphas drop `0x44`→`0x30`).
- Visual language: 0–2pt radii (use `Rectangle`, not `RoundedRectangle`), 1/1.5/
  2pt borders, corner brackets as filled rects (`cornerBrackets`),
  rotated-square markers (`NierMarker`), mono uppercase labels (components
  uppercase their own text — APIs take natural case). Geist = display, Geist
  Mono = HUD. No emoji, no SF Symbols in lists.
- Tracking is authored in `em` and converted to points (`em × size`) by
  `HudTextStyle.tracking`.

## Fonts

Geist + Geist Mono ship in the package bundle and register with CoreText on
first use (`SaltareFont.register`, via `Bundle.module`). Reference faces by
PostScript name: `Geist-Regular/Medium/SemiBold/Bold`, `GeistMono-Regular/
Medium`. Mono never exceeds the medium cut (the web system never loads mono
above 500) — a 600 request maps to `GeistMono-Medium`.

## Architecture conventions (carried from saltareos)

- **Pure domain layers** (`SaltareKit`) stay platform-free — no UIKit, no SDK
  types; platform/SDK types live at the edges, mirroring the Android
  `domain/`-is-pure-JVM rule.
- **Manual DI** via an `AppGraph`-style container — no heavy framework.
- **Agent loop invariants** (when `SaltareAgent` lands): one `tool_result` per
  `tool_use` id; parallel calls resolve into ONE user message; thinking blocks
  echo with untouched signatures; permission gates HOLD the request. Tool list
  order is the prompt-cache prefix — never reorder; MCP `saltare__*` tools
  append last.
- **Secrets** in Keychain (Secure Enclave + biometric); write-only from UI,
  never logged.
- **Models:** exact aliases only (`claude-opus-4-8`, `claude-sonnet-4-6`,
  `claude-haiku-4-5`).

## Build / test

```bash
cd Packages/SaltareHUD && swift build && swift test
```

Xcode 26 / Swift 6.3. Package builds on iOS 17+ / macOS 14+ (macOS lets the
design system build & test without a simulator). The app target requires iOS
18+. Use `ShowcaseView` previews for visual checks.

## Commits

Milestone-scoped commits (`iP*` prefixes). No Co-Authored-By trailers.
