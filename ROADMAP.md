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
│   └── SaltareAgent/    agent core DONE (iP2.1): AgentLoop + domain. Later:
│                        Anthropic SSE client, tool registry + executor, iOS tools
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

#### iP1.2 — Universal-input depth ✅ DONE (2026-06-14)
Every `SearchResult` row is now wired to its action. `swift test` (SaltareKit)
green (**63 tests**, +`ContactSearch`); app builds + runs.
- **Launch**: `canOpenURL` installed-filtering of the catalog (builtins always;
  externals gated, schemes declared in `LSApplicationQueriesSchemes`) → on the
  simulator the blank list correctly shrinks to builtins + Maps. App hits open
  via `UIKitLauncher` through the `RecordingLauncher` **choke point**, which
  records frecency first; the blank list re-orders by `Frecency`
  (`FrecencyStore`, `UserDefaults`, corruption-tolerant; injected `NowProviding`).
- **Contacts**: GRANT flow via `CNContactStore` — `.contactsGrant` row for
  name-like queries when undetermined; on grant, a debounced (250ms) native
  name-predicate search splices `.contact` rows before the agent stub; tap →
  `tel:`. Pure ranking in `SaltareKit.ContactSearch` (tested).
- **Calc**: copy-on-tap → pasteboard + transient HUD toast.
- **Settings links**: `openSettingsURLString` / notification settings; in-app
  routes deferred to iP3. **AgentStub**: placeholder toast until iP2.
- Dropped: **NEW tags** (iOS can't detect installs — no analog) and
  auto-launch-on-type (defaults off; deferred). Honest deltas, logged here.

#### iP1.3 — System reach + feel ✅ DONE (2026-06-14) — iP1 COMPLETE
The universal input now radiates onto the iOS surfaces Android can't reach.
App + widget extension both build; App Shortcuts metadata extracted.
- **App Intents + App Shortcuts** (`OpenSaltareIntent`, `SearchSaltareIntent` w/
  a query parameter; `SaltareShortcuts`) → Spotlight / Siri / Shortcuts, no user
  setup. `openAppWhenRun` routes through `CommandRouter` (shared singleton, since
  entry points can't reach `AppGraph`).
- **Deep links**: `saltare://search?q=…` via `.onOpenURL` → `CommandRouter` →
  `model.setQuery`. Scheme registered (`CFBundleURLTypes`); iOS routes it.
- **Widget extension** (`SaltareWidgets.appex`, embedded): a `SaltareSearchWidget`
  (systemSmall + accessoryRectangular/Inline) deep-linking via `widgetURL`, and
  an iOS 18 **`SaltareControl`** (Control Center / Lock Screen) opening the app.
  HUD-styled.
- **Feel**: light `Haptics.tap()` on every selection; VoiceOver labels + hints
  per `SearchResult` row.
- **Deferred (honest):** snapshot goldens of the surface (needs an app UI-test
  target + a snapshot lib — surface is screenshot-verified for now); full Dynamic
  Type (the HUD is fixed-size by design — VoiceOver covers a11y); CoreSpotlight
  *content* indexing → iP3 (needs workspace data).

### iP2 — On-device agent (`SaltareAgent`)
The crown jewel, sequenced like iP1 (pure core first).

#### iP2.1 — Agent core ✅ DONE (2026-06-14)
`Packages/SaltareAgent` pure-Swift package (iOS 17+/macOS 13+, no UIKit/SDK/
network — the Android `:agent` `domain/` + `loop/`). `swift test` green
(**14 tests**, the `AgentLoopTest` suite ported 1:1).
- `AgentLoop.run` — the manual tool loop as `async` + an `AsyncStream` wrapper,
  preserving every invariant: one `tool_result` per `tool_use` id; parallel
  calls → ONE `toolResults` message; `needsPermission` HOLDS the loop until
  `awaitPermission` resolves, then re-executes; assistant blocks (incl. thinking
  signatures) echoed verbatim; a failed/**cancelled** first request leaves
  history untouched (cancel-mid-stream tested).
- Domain: `AgentModel` (exact aliases, adaptive-thinking flag), `ToolSpec`/
  `ToolOutcome`/`ToolRunner`, `LlmClient`/`LlmRequest`/`LlmStreamEvent`,
  `AssistantBlock`/`HistoryMessage`/`AgentHistory`, `AgentEvent`,
  `SystemPromptText` (stable cache-prefix + volatile suffix), `JSONValue`
  (Sendable stand-in for `Map<String, Any?>`).

#### iP2.2 — Anthropic client + key vault ✅ DONE (2026-06-14)
The Messages API boundary, Foundation-only in `SaltareAgent`. `swift test` green
(**26 tests**); app builds with the Keychain store.
- `AnthropicRequest` — the request builder (`POST /v1/messages`): system =
  `stable` (with `cache_control: ephemeral` breakpoint) + `volatile` suffix;
  `thinking: {type: adaptive}` on Opus/Sonnet, omitted on Haiku (`budget_tokens`
  400s); tools carry `input_schema`; tool/`tool_result`/thinking-signature
  echo. Tested against the JSON wire shape.
- `AnthropicSSEParser` — accumulates `content_block_start/delta/stop` →
  `message_delta`/`message_stop` into `LlmStreamEvent`s; text deltas stream,
  tool_use input-JSON reassembles, thinking signatures survive. Tested against
  scripted event streams.
- `AnthropicLlmClient` — `URLSession.bytes` SSE stream; `AnthropicConfig` takes
  an `apiKey` closure so the data layer stays Keychain-free. `DemoLlmClient`
  runs keyless.
- `KeychainApiKeyStore` (app target) — device-only Keychain (`...ThisDeviceOnly`).
  Not biometric-gated by default (a Face ID prompt per turn is hostile — the
  passcode is the boundary; biometric `SecAccessControl` is the documented
  upgrade path). Verified by reading the JSON-port via `JSONValue` Codable.

#### iP2.3 — iOS tools (the toolbox) ✅ DONE (2026-06-15)
`SaltareAgent` `swift test` green (**31 tests**); app builds with the catalog
wired in.
- **Package (pure, tested):** `ToolRegistry` (stable order = prompt-cache prefix;
  `remoteTools` MCP `saltare__*` append last), `ToolExecutor` (dispatch +
  injected `permissionGranted` pre-check → `.needsPermission` holds the loop),
  `LauncherCapabilities`, `Dictionary.str/int` input accessors.
- **App tools (`AgentTools.local`, stable order):** `open_app` (via
  `CommandSurfaceCapabilities` → the command-surface catalog + `canOpenURL`);
  visible-intent tools `phone_call`/`send_sms`/`send_email`/`open_url`/`show_map`
  (`UIApplication.open`); `device_status` (battery + `NWPathMonitor` network);
  GRANT-gated `contacts_search`/`calendar_upcoming`/`create_calendar_event`
  (`CNContactStore` / `EKEventStore`). `AgentPermissions` maps the GRANT strings
  to iOS authorization (status + request); `AgentAssembly` wires registry →
  executor → loop → Anthropic/Demo client.
- **iOS deltas (no API):** dropped `set_alarm`/`set_timer`/`share_text`; calendar
  create uses EventKit **write** (Android opens an editor); `device_status` omits
  DND/volume (no public read).

#### iP2.4 — Agent UI + entry ✅ DONE (2026-06-15) — iP2 COMPLETE
The agent sheet — a HUD surface with a streaming transcript, tool chips, the
permission GRANT, a model picker, and an API-key settings screen. `SaltareAgent`
`swift test` green (**37 tests**); app builds + the sheet renders on the sim.
- **Package (pure, tested):** `ChatMessage`/`ChipStatus`/`AgentPhase` +
  `TranscriptReducer` (folds `AgentEvent`s into the transcript — live streaming
  message, chips rewritten by id). Ported 1:1 with the `TranscriptReducerTest`.
- **App:** `AgentSessionModel` (`@Observable`, drives `loop.runStream`, bridges
  the permission round-trip via a `CheckedContinuation`, gates on `hasKey`);
  `AgentSheet` (transcript rows, tool chips by status tone, GRANT panel, model
  picker, input); `AgentSettingsView` (Keychain key entry).
- **Wiring:** the `AgentStub` row and `saltare://agent` builtin →
  `CommandRoute.agent` sheet; the `saltare://settings/agent` link →
  `agentSettings`. `AppGraph` builds the `AgentAssembly`.
- **Verification note:** a live conversation needs an Anthropic key + taps the
  CLI can't drive — the transcript logic is unit-tested, the sheet is
  screenshot-verified (presented via an env-gated UI-test hook).

### iP3 — Deep `saltare` integration
The original thesis. The server already exposes everything (REST `/api/v1/*`,
native auth `POST /api/v1/auth/token` → `sk_sal_` + `rt_sal_`, MCP `/mcp`, and an
**inference proxy** `/api/v1/inference/v1/messages` — server-held Anthropic key +
credit metering, so the agent can run with just the workspace token).

#### iP3.1 — Workspace client core ✅ DONE (2026-06-15)
`Packages/SaltareWorkspace` pure-Swift package (iOS 17+/macOS 13+, Foundation
only). `swift test` green (**12 tests**) — models decode the exact serializer
shapes; endpoints + request building tested.
- **Models** (`Decodable`, ported from `Api::V1::*Serializer`): `AuthTokens`
  (device session), `CurrentSession` (`/me`), `WorkspaceTask`, `Channel`,
  `Message`, `Agent`, `Document`, `ActorRef`, the `{data:…}` envelope + the
  `{error:{code,message}}` envelope.
- **`WorkspaceEndpoint`** — pure request builders (auth token/refresh/signout,
  me, tasks, channels, messages, agents+`message`, documents); correct param
  nesting (`{task:{…}}`, `{message:{channel_id,body}}`, `content`,
  `email_address`); auth endpoints skip the bearer gate.
- **`WorkspaceClient`** — `URLSession` executor; Bearer auth via a
  `TokenProviding` seam; unwraps `{data:…}` for resources, decodes auth/`me`
  directly; surfaces the `{error}` envelope as `WorkspaceError.api`.

#### iP3.2 — Auth + token vault + inference proxy ✅ DONE (2026-06-15)
Native sign-in wired end-to-end; app builds + the sign-in screen renders.
- **`TokenVault`** (Keychain, `...ThisDeviceOnly`) — stores `sk_sal_` access +
  `rt_sal_` refresh + workspace/user metadata; conforms to `TokenProviding` and
  is the shared source of truth for the sign-in UI and the agent.
- **`WorkspaceSession`** (`@Observable`) — `signIn(email:password:)` →
  `WorkspaceClient.signIn` → vault; `signOut`; `refresh()` (rotate on 401);
  maps `WorkspaceError` to a friendly banner.
- **`SignInView`** — HUD email/password form; signed-in state shows the
  workspace + sign-out.
- **Inference proxy**: `AnthropicConfig` now resolves an `AnthropicEndpoint`
  (base URL + `AnthropicCredential`) per request — `AgentAssembly` prefers the
  workspace token (→ `/api/v1/inference` with `Authorization: Bearer`, so the
  server holds the Anthropic key + meters credits) and falls back to a pasted
  key (→ `api.anthropic.com` with `x-api-key`). The agent now runs with **no
  on-device key** once signed in.
- **Wiring:** `AppGraph` holds the `TokenVault` + workspace base URL; the
  `saltare://signin` builtin → `CommandRoute.signIn`. Live sign-in needs a
  saltare account + server — screen + wiring are build/screenshot-verified.

#### iP3.3 — Workspace surfaces
HUD-styled Chat (channels/threads/DMs/agent-DMs), Tasks, Documents, Agents over
the REST client; the agent's MCP `saltare__*` tools (`ToolRegistry.remoteTools`).

#### iP3.4 — Realtime + system reach
Action Cable Swift client (token-authed), APNs push (server-side done),
CoreSpotlight content indexing, Live Activities, workspace Widgets, Share
extension.

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
