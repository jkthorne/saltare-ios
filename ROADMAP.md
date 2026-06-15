# saltare-ios roadmap

The single source of truth for the native iOS app: what exists, what's in
flight, and what's next. The iOS counterpart to `~/Developer/saltareos`
(the Android take) — same NieR-HUD identity, same on-device-agent thesis,
deeply integrated with the `saltare` Rails workspace.

## Vision

A genuinely **native SwiftUI app** (not the Hotwire Native webview shell in
`saltare/mobile/ios`) that brings the saltareOS experience to iPhone:

- the **universal-input command surface** as the front door,
- an **on-device Claude agent that treats iOS itself as a toolbox**,
- the **NieR-HUD design system** rendered natively,
- a **NieR keyboard extension**,

all wired into a live `saltare` workspace through **MCP + the REST API**, and
pushed system-wide via the iOS surfaces Android doesn't have (App Intents /
Siri, Spotlight, Widgets, Controls, Live Activities, Share extension).

Where iOS forbids an Android concept (replacing the launcher, the IME default,
the ASSISTANT role), map it to the nearest system-blessed surface rather than
fight the platform — and say so honestly.

## Concept → iOS mapping

| saltareOS (Android) | iOS realization |
|---|---|
| `:hud` foundation-only Compose library | **`SaltareHUD`** foundation-only SwiftUI package, ported from the same `application.css` |
| `:launcher` universal input (HOME) | App **Command surface** + App Shortcuts/Spotlight/Widget/Control entry points (no SpringBoard replacement) |
| `:agent` on-device Claude (phone-as-tools, MCP) | Native **`SaltareAgent`**: Anthropic SSE tool loop, iOS-capabilities-as-tools, GRANT flow, Keychain key, MCP `saltare__*` |
| `:keyboard` NieR IME | **`SaltareKeyboard`** Keyboard Extension |
| ROM-level HOME+ASSISTANT defaults | App Intents + Siri + Action button + Control + Share extension |

## Architecture

```
saltare-ios/
├── Packages/
│   ├── SaltareHUD/      design system (foundation-only SwiftUI) + Showcase + token tests   ← iP0 (DONE)
│   ├── SaltareKit/      pure-Swift domain. Search engine DONE (iP1.1): Calculator,
│   │                    UnitConvert, Frecency, SearchResult, AppSearch. Later:
│   │                    AgentLoop core, Anthropic + MCP + REST clients
│   └── SaltareAgent/    tool registry + executor (domain in pkg, iOS tools in app target)
├── Saltare/             SwiftUI App (XcodeGen project.yml). Command surface DONE (iP1.0);
│                        later: Chat · Tasks · Docs · DBs · Agents · Settings
├── SaltareKeyboard/     Keyboard Extension
├── SaltareWidgets/      WidgetKit + Live Activities + Controls
├── SaltareShare/        Share Extension
└── SaltareIntents/      App Intents (Siri / Shortcuts / Spotlight)
```

- **Min iOS 18 / build against the latest SDK** (App Intents, interactive
  widgets, Controls, Live Activities, `@Observable`).
- **Disciplines carried over from saltareos:** pure domain layer (platform
  types at the edges), manual DI (an `AppGraph`-style container, no heavy
  framework), Keychain for secrets, snapshot goldens.
- **Design source of truth stays `saltare/app/assets/tailwind/application.css`**
  — port tokens from it, never invent. CSS `#RRGGBBAA` → `0xAARRGGBB`
  (the `Color(argb:)` helper), enforced by `SaltareColorsTests`.

## Phases

### iP0 — `SaltareHUD` design system ✅ DONE (2026-06-14)
Foundation-only SwiftUI package, no UIKit chrome. Ported token-for-token from
`:hud`:
- **Theme:** `SaltareColors` (dark "android" + light "parchment", full
  hand-written palettes), `SaltareTypography` (Geist/Geist Mono, em→pt
  tracking), `SaltareSpacing`, environment-based `saltareTheme(...)` with
  `hudContentColor`/`hudTextStyle` (the `LocalContentColor`/`LocalTextStyle`
  analogs).
- **Foundation:** `cornerBrackets` (filled-rect L brackets), `hudGlow` (two
  CSS halos), `HudIndicationStyle` (press-scale 0.98 + focus ring — the ripple
  replacement), `scanLines`.
- **Components:** `HudText`, `HudButton`, `HudPanel`/`NierPanel`/`CutPanel`/
  `HudDivider`, `HudTextField`, `NierHeading`, `NierMarker`, `NierReadout`/
  `NierTimestamp`, `Badge`, `NierCheck`, `ScanBar`, `NierDiamond`.
- **Showcase:** `ShowcaseView` gallery (dark + parchment previews).
- **Tests:** `SaltareColorsTests` (exact `0xAARRGGBB` token assertions, the
  `SaltareColorsTest.kt` analog) + `SaltareTypographyTests`. `swift test` green.

### iP1 — Command surface (universal input)
The launcher concept as the app's home + system entry points. Four milestones
mirroring the Android L1→L4 cadence (search core → universal input → system
depth → feel). The app target is built with **XcodeGen** (a checked-in
`project.yml`; the `.xcodeproj` is generated, never committed).

iOS-honest deltas from Android (each mapped, not faked):
- **No app enumeration** → a curated `AppCatalog` + saltare destinations,
  probed with `canOpenURL` (declared schemes, ≤50). Unknown names fall through
  to the AgentStub (the intended design).
- **Settings deep-links are mostly private API** → ship only the public ones
  (`openSettingsURLString`, `openNotificationSettingsURLString`) and repurpose
  the row for in-app settings/permission jumps; never `App-Prefs:`.
- **Work-profile / quiet-mode** `SearchResult` cases dropped (no iOS analog).
- **Auto-launch-as-you-type** logic ported but defaults OFF (launching another
  app yanks the user out of saltare).

#### iP1.1 — Search engine ✅ DONE (2026-06-14)
`Packages/SaltareKit` pure-Swift package (iOS 17+/macOS 13+, no UIKit/SwiftUI —
the "domain is pure JVM" rule). `swift build` + `swift test` green (**59 tests**).
Ported 1:1 from the Android `:launcher` `domain/`, including the Kotlin test
suites:
- `SearchResult` (trimmed enum, same row order **Calc → AppHits →
  SettingsLinks(≤2) → Contacts → AgentStub**), `AppEntry`/`AppKey`.
- `AppSearch` — normalize/tokens (diacritic-strip, punctuation-as-word-break),
  rank (exact > word-prefix > substring > subsequence≥3), stable assembly,
  `withContacts` splice, `autoLaunchCandidate` guard rails.
- `Calculator` (shunting-yard, unary minus, `%`/`^` right-assoc, comma-decimals,
  non-finite → nil), `UnitConvert` (length/mass/data/temp, affine temp),
  `Frecency` (`count × 2^(−ageDays/14)`, read-time decay, prune to 100).
- `SettingsLinks` (iOS catalog) + `AppCatalog` (curated externals + builtins).

#### iP1.0 — App target + DI ✅ DONE (2026-06-14)
The `Saltare` app target (SwiftUI lifecycle, dark-locked, iOS 18+), generated by
**XcodeGen** from `project.yml` (the `.xcodeproj` is gitignored). Builds for the
simulator and runs:
- `AppGraph` — manual-DI container (Sendable, holds the `SearchProviding` seam),
  mirroring the Android `AppGraph`.
- `SearchEngine` — wraps `SaltareKit` (`AppSearch` over `AppCatalog` +
  `SettingsLinks`) behind a `SearchProviding` protocol.
- `CommandSurfaceModel` — `@Observable` VM; deterministic, synchronous.
- `CommandSurfaceView` + `CommandRow` — the universal-input field over the
  results list; every `SearchResult` case rendered with HUD components (a
  compile-enforced touch point). Row *actions* are stubbed (`select(_:)`) for
  iP1.2. Verified on the iOS 26.5 simulator: brand + scan bar + input + the
  blank-query catalog list render under `.saltareTheme(.dark)`.

#### iP1.2 — Universal-input depth
Render every `SearchResult` row; curated app catalog + URL-scheme launch;
Contacts GRANT + CALL/SMS rows (debounced `CNContactStore`); settings/permission
links; AgentStub row (placeholder tap until iP2); copy-on-tap Calc;
frecency-ordered blank list + NEW tags; the `RecordingLauncher` choke point.

#### iP1.3 — System reach + feel
App Shortcut ("Search/Ask saltare") via App Intents, CoreSpotlight donation, a
Home/Lock-Screen Widget with a deep-linked quick-input, an iOS Control; haptics,
VoiceOver, Dynamic Type, snapshot goldens of the surface states.

### iP2 — On-device agent (`SaltareAgent`)
- Manual streaming tool loop over the Anthropic API via `URLSession` SSE,
  preserving the invariants: one `tool_result` per `tool_use` id; parallel
  calls → one user message; thinking blocks echoed with untouched signatures;
  permission gates HOLD the request. Same aliases (`claude-opus-4-8`,
  `claude-sonnet-4-6`, `claude-haiku-4-5`); adaptive thinking on Opus/Sonnet.
- iOS as the toolbox: visible-intent analogs (`tel:`/`sms:`/`mailto:`/MapKit/
  EventKit/open_app) + read tools behind a GRANT flow (Contacts, Calendar/
  Reminders, Location, `device_status`) + App-Intents invocation.
- Secrets in Keychain (Secure Enclave + biometric); demo mode without a key;
  Siri/App-Intents assistant entry. Tool registry order is the prompt-cache
  prefix — never reorder; MCP tools append last.

### iP3 — Deep `saltare` integration
- **Auth** (the one real server gap): `POST /api/v1/auth/token` (email/password
  → scoped `sk_sal_` token) stored in Keychain. API-key paste bootstraps until
  then.
- **MCP client** → `saltare__*` workspace tools (Streamable HTTP, bearer token).
- **REST surfaces** over `/api/v1/*`: HUD-styled Chat (channels/threads/DMs/
  agent-DMs), Tasks (list/board/calendar), Documents, Databases, Agents.
- **Realtime** via an Action Cable Swift client (needs token auth on the cable
  connection — small server follow-on).
- **Push** (APNs already built server-side) via the token-authed device-token
  path; taps deep-link to the right surface.
- **CoreSpotlight** indexing (the web command palette → OS search),
  **Live Activities / Dynamic Island** (agent thinking, pipelines, voice),
  **Widgets**, **Share extension**, **App Intents**.

### iP4 — `SaltareKeyboard` extension
`UIInputViewController` hosting SwiftUI: port the pure reducer (shift/caps/
composing), symbols/numeric/inputType layouts, long-press alternates, the 30k
autocorrect dictionary (mmap trie) + suggestion strip, corner-bracket frame.
Constraints: Full Access for haptics/network; ~60MB memory cap.

### iP5 — Polish
LiveKit voice, full VoiceOver/Dynamic Type, fastlane + TestFlight +
`PrivacyInfo.xcprivacy`, App Store.

## Server-side dependencies (mostly additive — most scaffolding already exists)

1. `POST /api/v1/auth/token` — email/password → scoped mobile token (the one
   genuine gap; everything else works today with a pasted API key).
2. Token auth on Action Cable for native realtime (web uses the session cookie).
3. Native push registration that accepts a bearer token (current
   `POST /mobile/device_tokens` is webview/cookie-driven).

Already present server-side: MCP (`/mcp`), REST (`/api/v1/*`), `sk_sal_` scoped
tokens, APNs delivery (`DeviceToken`, `MobilePushNotificationJob`,
`Notifications::PushPayload`).

## Risks / honest constraints

- No launcher / IME-default / assistant-role on iOS → recovered via Spotlight +
  Widgets + Controls + Siri/App Intents.
- Keyboard extension memory + Full-Access limits → mmap dictionary, degrade
  gracefully.
- No mature official Anthropic Swift SDK → hand-rolled SSE client.
- App Store review: API-key paste UX + a clear non-webview value story.

## Working agreements

- Milestone-scoped commits (`iP*` prefixes). No Co-Authored-By trailers.
- Pure domain layers stay platform-free; port tokens from `application.css`,
  never invent. Snapshot goldens re-recorded per milestone.
