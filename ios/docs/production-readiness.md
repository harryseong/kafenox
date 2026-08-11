# iOS Production-Readiness Report

_Evaluated against 2026 iOS / Swift best practices. Generated Aug 11, 2026._

---

## Summary Scorecard

| Area | Grade | Notes |
|---|---|---|
| Swift 6 / strict concurrency | ✅ Excellent | Fully adopted, intentional isolation strategy |
| Architecture / module separation | ✅ Excellent | Compiler-enforced, well-documented |
| `@Observable` / SwiftUI patterns | ✅ Current | Fully migrated from `ObservableObject` |
| Testing (Swift Testing) | ✅ Strong | Good coverage, good test doubles |
| Configuration / secrets | ✅ Good | Keychain for keys, xcconfig for URLs |
| Logging | ✅ Excellent | `OSLog` with privacy annotations |
| Accessibility | ⚠️ Partial | Labels present; no reduce-motion support, no full audit |
| Dependency injection consistency | ⚠️ One gap | `CatalogView.performDelete` bypasses injected repo |
| UI test coverage | ❌ Absent | No snapshot or UI tests |
| Push notifications / offline | ⚠️ Documented limitation | Local notifications only, documented in ADR |

---

## 1. Swift 6 / Strict Concurrency — ✅ Excellent

Every package declares `swiftLanguageMode(.v6)`, meaning the compiler enforces
data-race safety at compile time rather than emitting warnings. The isolation
strategy is intentional and well-layered:

- **`Core` and `Networking`** are deliberately nonisolated — their value types
  cross actor boundaries (`actor APIClient` decodes off the main actor; `Coffee`
  is `Sendable`).
- **`Features` and `DesignSystem`** use `.defaultIsolation(MainActor.self)` so
  UI-adjacent code needs no per-declaration annotation noise.
- `UploadQueueMonitor` is `@MainActor @Observable`, and its
  `UNUserNotificationCenterDelegate` conformance is correctly marked `nonisolated`.
- Structured concurrency is used correctly throughout — `Task { [weak self] in
  … }` with `Task.isCancelled` checks, `CancellationError` caught separately,
  and `cancelUpload()` cancels in-flight `Task` references before releasing them.

**Minor rough edge:** `CoffeeRepository.updateCoffee` takes `[String: Sendable]`
instead of a typed `CoffeeUpdate` struct. This is a deliberate trade-off for the
DynamoDB flat-map shape but sacrifices call-site safety and discoverability.

---

## 2. Architecture & Module Separation — ✅ Excellent

The four-package split is compiler-enforced rather than a convention:

```
Core  ──▶  Networking
  │              │
  └──▶  DesignSystem
              │
           Features  ◀──  App target (@main, RootView, tab shell only)
```

- **`Core`** — domain models, `CoffeeRepository` protocol, configuration,
  loggers. Foundation and OSLog only; testable natively on macOS without a
  simulator.
- **`DesignSystem`** — palette, typography, shared components.
- **`Networking`** — the `URLSession`-backed `APIClient` implementing
  `CoffeeRepository`.
- **`Features`** — all five feature areas and their view models.

The ADRs in `docs/adr/` document the reasoning behind this layout (including why
one-package-per-feature was rejected) — an unusually strong signal of a mature
project.

---

## 3. Observation Framework — ✅ Current

All view models use `@Observable` (the macro that supersedes `ObservableObject`).
Views consume state via `@Environment`, `Bindable`, and direct property access.
`@ObservedObject`, `@StateObject`, and `@Published` are absent — the codebase
has fully migrated to the iOS 17+ model.

---

## 4. Testing — ✅ Strong

The project uses **Swift Testing** (`@Suite`, `@Test`, `#expect`) — the framework
that shipped with Xcode 16 and is now idiomatic over XCTest.

**What's well covered:**

- `CatalogViewModel` — loading, filtering, mutation, and in-flight scan pinning.
- `UploadQueueMonitor` — state transitions, idempotency, transient failure
  retry, background task lifecycle, and notification delivery.
- `DetailViewModel` and `InsightsViewModel` have their own test suites.

**Test infrastructure quality:**

- `StubCoffeeRepository` is a hand-written `actor` — no mocking framework needed,
  and it stops compiling the moment `CoffeeRepository` changes.
- `SpyUploadQueueServices` injects a seam for `UNUserNotificationCenter` and
  `UIApplication.beginBackgroundTask`, both of which would trap in a bare test
  process without it.
- `waitUntil` polls on 20 ms ticks rather than fixed `sleep` — not flaky.

**What's missing:**

- `AskAIViewModel.send()` has no test coverage.
- No UI tests, snapshot tests, or integration tests against a staging environment.

---

## 5. Configuration & Secrets — ✅ Good

- The API key is stored in the **Keychain** via `KeychainStore`, not hardcoded
  or bundled in the binary.
- The base URL is injected via `.xcconfig` → `Info.plist` → `AppConfiguration`,
  with a `preconditionFailure` on malformed values — fast failure at launch
  rather than a silent wrong URL.
- `Debug.xcconfig` contains a real AWS API Gateway URL. Confirm this is either
  rotatable on exposure or protected by a `.xcconfig.local` / `.gitignore` pattern.

---

## 6. Logging — ✅ Excellent

`Logger` (OSLog) is used everywhere via subsystem/category pairs defined once
in `AppLog.swift`. Privacy annotations (`privacy: .public`) are applied only to
non-user data (HTTP status codes, photo IDs). `print()` is absent. This is
exactly what Apple's Instruments and Console.app workflow expects.

---

## 7. Accessibility — ⚠️ Partial

**Present:**

- `accessibilityHidden(true)` on decorative icons.
- `accessibilityLabel` on icon-only buttons (e.g. the layout toggle).
- Empty states and error states are implemented with readable copy.

**Missing / unverified:**

- `PressScaleButtonStyle` does not check `UIAccessibility.isReduceMotionEnabled`
  — scale animations should be skipped for users who have enabled Reduce Motion.
- No `accessibilityValue` or `accessibilityHint` on interactive controls where
  they would add context.
- No VoiceOver end-to-end audit on record.

---

## 8. Dependency Injection Consistency — ⚠️ One Gap

`CatalogView.performDelete()` calls `APIClient.shared` directly instead of
routing through the `repository` already injected into `CatalogViewModel`:

```swift
// CatalogView.swift — bypasses the injected repository
try await APIClient.shared.deleteCoffee(photoId: coffee.photoId)
```

This breaks the dependency inversion the rest of the architecture maintains and
means `CatalogView` cannot be exercised in isolation without a live network.
The fix is to add a `deleteCoffee(photoId:)` method to `CatalogViewModel` and
call that instead.

---

## 9. Background Execution — ✅ Well-Considered

`UploadQueueMonitor` correctly uses `UIApplication.beginBackgroundTask` to
extend execution time while waiting for upload completion. The ADR documents the
deliberate choice of local notifications over APNs and its trade-off: notifications
only fire while the process is alive (foreground, or the ~30 s background window).
This is acknowledged and proportionate to the current scope.

---

## 10. Project Structure & Tooling — ✅ Modern

- **XcodeGen** (`project.yml`) keeps `.pbxproj` generated and reviewable — no
  merge conflicts in Xcode project files.
- **`swift-format`** config at the repo root with explicit rule overrides.
- Build settings live in `.xcconfig` files, not embedded in the Xcode inspector.
- Deployment target is **iOS 26 / Swift 6.2** — current as of the Xcode 26
  release cycle.

---

## Priority Action Items

| Priority | Item |
|---|---|
| High | Fix `CatalogView.performDelete` to use the injected `CoffeeRepository` |
| Medium | Add `@Test` coverage for `AskAIViewModel.send()` |
| Medium | Audit `PressScaleButtonStyle` for `UIAccessibility.isReduceMotionEnabled` |
| Medium | Confirm `Debug.xcconfig` API URL is safe to commit (rotatable / dev-only) |
| Low | Full VoiceOver pass; add `accessibilityHint` / `accessibilityValue` where missing |
| Low | Add UI / snapshot tests for at least the catalog and detail screens |
| Low | Replace `[String: Sendable]` in `updateCoffee` with a typed update type |
