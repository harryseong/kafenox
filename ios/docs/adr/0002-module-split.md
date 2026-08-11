# 0002. Four local packages, one of them all the features

**Status:** accepted

## Context

The app grew to ~4,100 lines in a single Xcode target. Every type was
`internal`, so nothing prevented a view from reaching into the API client or a
model from importing SwiftUI; the only record of the build was `.pbxproj`,
which does not review usefully.

The textbook layout is one package per feature. That does not fit here. The
feature areas are not independent: Detail mutates the same coffee list
Catalog owns, Insights derives entirely from it, and the upload queue patches
it from a background poll. Splitting them into separate packages would force
that shared store up into `Core` — turning a genuine domain package into a
dumping ground — and buy nothing, since no feature is separately shippable.

## Decision

Four packages:

- **`Core`** — domain models, `CoffeeRepository`, configuration, loggers.
  Foundation and OSLog only, so it stays testable natively and usable off the
  main actor.
- **`DesignSystem`** — palette, typography, shared components.
- **`Networking`** — the `URLSession` client implementing `CoffeeRepository`.
- **`Features`** — all five feature areas and their view models.

Nothing depends on `Features`. The app target holds only `@main`, `RootView`,
and the tab shell.

Isolation is set per package rather than globally: `Core` and `Networking` stay
nonisolated (their values cross actor boundaries — the client decodes off the
main actor), while `DesignSystem` and `Features` use
`.defaultIsolation(MainActor.self)` so UI code needs no annotation.

## Consequences

The compiler now enforces the layering: `Core` cannot import SwiftUI, and a
feature cannot quietly reach into the transport. View models take
`any CoffeeRepository`, which is what made the state tests possible at all.

The cost is that `Features` is the package most likely to keep growing, and it
has no internal boundary — a view in Catalog *can* import a type from Settings.
Split it when two feature areas start fighting over the same file, or when it
outgrows roughly 3,000 lines; the shared catalog store moving to `Core` is the
first step when that happens.
