# iOS Production-Readiness Report

_Evaluated against 2026 iOS / Swift best practices. Re-evaluated Aug 11, 2026
after the readiness follow-up (PR #17)._

---

## Summary Scorecard

| Area | Grade | Notes |
|---|---|---|
| Swift 6 / strict concurrency | ✅ Excellent | Fully adopted, intentional isolation strategy |
| Architecture / module separation | ✅ Excellent | Compiler-enforced; app target is composition-only |
| `@Observable` / SwiftUI patterns | ✅ Current | Fully migrated from `ObservableObject` |
| Testing (Swift Testing) | ✅ Excellent | Broad VM coverage including Ask AI; good doubles |
| Dependency injection consistency | ✅ Excellent | Repository and settings injected; prior bypass fixed |
| Configuration / secrets | ✅ Good | Keychain for keys; xcconfig for URLs; URL safety documented |
| Logging | ✅ Excellent | `OSLog` with privacy annotations |
| Accessibility | ✅ Strong | ADR 0004; Dynamic Type, Reduce Motion, VoiceOver actions |
| CI / tooling | ✅ Excellent | Format lint, package tests, warnings-as-errors |
| UI test coverage | ❌ Absent | No snapshot or UI tests |
| Push notifications / offline | ⚠️ Documented limitation | Local notifications only; see ADR 0003 |
| Production API stage | ⚠️ Gap | Release still targets the `/dev` API stage |

---

## Changes since the previous report

The prior audit's priority list has been acted on:

| Prior item | Outcome |
|---|---|
| High — `CatalogView.performDelete` used `APIClient.shared` | Fixed via `CatalogViewModel.delete(photoId:)` |
| Medium — No `AskAIViewModel.send()` tests | Added (round-trip, trim, history, errors, reentrancy, model) |
| Medium — `PressScaleButtonStyle` ignored Reduce Motion | Gated; scan `repeatForever` animations and queued spring also gated |
| Medium — Confirm committed `Debug.xcconfig` API URL | Documented intentional: URL is not a credential; key stays in Keychain |
| Low — Typed `updateCoffee` payload | `CoffeeUpdate` replaces `[String: Sendable]` at call sites |
| Low — VoiceOver / hints / values | Expanded beyond labels (see §7 and ADR 0004) |

Follow-up also fixed issues the first report missed: `EditCoffeeView` had no injected repository; `AskAIViewModel` / `ScanViewModel` read `SettingsStore.shared` directly; Dynamic Type used `UIFontMetrics` and did not update live — now `.appFont` via `@ScaledMetric`.

---

## 1. Swift 6 / Strict Concurrency — ✅ Excellent

Every package declares `swiftLanguageMode(.v6)`. Isolation remains intentional:

- **`Core` and `Networking`** are nonisolated — value types cross actor boundaries.
- **`Features` and `DesignSystem`** use `.defaultIsolation(MainActor.self)`.
- Structured concurrency (`Task { [weak self] }`, cancellation, background tasks) is unchanged and sound.

---

## 2. Architecture & Module Separation — ✅ Excellent

```
Core  ──▶  Networking
  │              │
  └──▶  DesignSystem
              │
           Features  ◀──  App target (@main, RootView, tab shell only)
```

The app target compiles only `KafenoxApp`, `RootView`, and `KafenoxTabBar`. Feature code lives in packages. ADRs in `docs/adr/` still document the layout and trade-offs.

---

## 3. Observation Framework — ✅ Current

All view models use `@Observable`. No `ObservableObject` / `@Published` / `@StateObject` in the shipping packages.

---

## 4. Testing — ✅ Excellent

Swift Testing throughout. Coverage now includes:

- `CatalogViewModel` — load, filter, mutation, delete, in-flight scan pinning
- `AskAIViewModel` — send path, history, errors, busy gating, selected model
- `DetailViewModel` / `InsightsViewModel` / `UploadQueueMonitor`
- `CoffeeUpdate` payload / emptiness rules
- Core domain helpers (`Coffee` status / display)

Infrastructure quality is unchanged: `StubCoffeeRepository` actor, `SpyUploadQueueServices`, `waitUntil` polling.

**Still missing:** UI tests, snapshot tests, staging integration tests.

---

## 5. Configuration & Secrets — ✅ Good

- API key: Keychain only (`KeychainStore`), never committed.
- Base URL: `.xcconfig` → `Info.plist` → `AppConfiguration`, with launch-time failure on malformed values.
- Committed API Gateway host is intentional on a public repo: it is not a credential; requests require `x-api-key`; usage plan throttles abuse. Documented in `ios/README.md`.

**Remaining gap:** `Release.xcconfig` still points at the `/dev` stage until a prod stage exists.

---

## 6. Logging — ✅ Excellent

`Logger` / `AppLog` with privacy annotations. No `print()` in package sources.

---

## 7. Accessibility — ✅ Strong

Documented in ADR 0004. Shipping behavior includes:

- Semantic actions on swipeable catalog rows (open / Edit / Delete)
- Labeled text fields in `EditCoffeeView`
- `accessibilityValue` + `accessibilityAdjustableAction` on the rating strip
- Hints on key CTAs (Ask AI, verify)
- Live Dynamic Type via `@ScaledMetric`-backed `.appFont`
- Reduce Motion on decorative motion (scan animations, press scale, queued spring)

**Still manual:** VoiceOver / content-size / Reduce Motion checks in `ios/README.md` are not automated; easy to regress.

---

## 8. Dependency Injection — ✅ Excellent

Prior gap is closed. Catalog delete, detail delete/verify/rate, edit save, Ask AI, and scan upload all go through injected `CoffeeRepository` (default `APIClient.shared`). Settings are injectable for tests.

---

## 9. Background Execution — ✅ Well-Considered

Unchanged: `beginBackgroundTask` + local notifications; APNs deferred (ADR 0003). Proportionate for current scope.

---

## 10. Project Structure, CI & Tooling — ✅ Excellent

- XcodeGen + xcconfig + `swift-format`
- Deployment target iOS 26 / Swift 6.2 packages
- CI (`.github/workflows/ios.yml`): format lint, Core `swift test`, Features `xcodebuild test`, app build with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

---

## Priority Action Items

| Priority | Item |
|---|---|
| Medium | Point `Release.xcconfig` at a dedicated prod API stage when one exists |
| Medium | Add UI / snapshot tests for catalog → detail → verify and scan → queued |
| Low | Keep running (or automate) the README VoiceOver / Dynamic Type / Reduce Motion checklist |
| Low | APNs if scan-complete notifications must fire after process death |
| Low | Retry path for failed extractions (today: delete and rescan) |
| Low | Revisit `list_coffees` DynamoDB scan with GSIs past ~5–10k items |
