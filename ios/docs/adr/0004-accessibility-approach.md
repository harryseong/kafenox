# 0004. Accessibility: custom controls, type scaling, and motion

**Status:** accepted

## Context

The app's UI is largely custom — a bespoke tab bar, a swipe-to-reveal list
row, a ten-segment rating strip, icon-only circular buttons — because the v3
design does not use stock SwiftUI controls. Custom controls carry none of
UIKit's built-in accessibility, so each one had to be given semantics
deliberately. An audit found labels present but three defects behind them.

## Decisions

### Custom controls get one semantic element, not their parts

`SwipeableCoffeeRow` was readable but not activatable: it uses `.onTapGesture`
rather than a `Button` (deliberately — a `Button` fires on touch-up even when
the touch was a horizontal swipe, which made swipes open the wrong screen), and
its Edit/Delete buttons were reachable only by physically dragging. VoiceOver
therefore could not open, edit, or delete a coffee at all.

The row now carries `.isButton` plus `.accessibilityAction` for open, Edit, and
Delete, and the underlying swipe buttons are `.accessibilityHidden`. The
gesture stays for sighted users; the actions are the equivalent route.

The same shape applies elsewhere: the rating strip is one adjustable element
with a value and an `accessibilityAdjustableAction` rather than ten anonymous
22pt targets, and each flavor-note chip is one element with a "Remove" action.

### Text fields carry their own label

`EditCoffeeView` rendered `TextField("", text:)` with the caption as a sibling
`Text`, so seven fields announced as an unnamed "text field". The shared
`field(_:text:)` helper now puts the label on the field and hides the caption
from VoiceOver — one fix for all seven.

### Type scales through `@ScaledMetric`, per-role

`Font.system(size:)` is a *fixed* size and ignores Dynamic Type entirely; the
app's text did not scale at all until this was found. An intermediate fix using
`UIFontMetrics` scaled correctly but resolved once at body-evaluation time, so
a text-size change while the app was running did nothing until relaunch.

The type ramp is now a `@ScaledMetric`-backed `ViewModifier` (`.appFont(_:weight:)`),
which is a `DynamicProperty` and re-reads the environment, so text resizes live.
Each design size scales against the system text style nearest it rather than
all against `.body`, because Apple's curves differ by role — scaling a 32pt
masthead on the caption curve pushed it off the screen at accessibility sizes.

Mastheads and tab labels carry `minimumScaleFactor` so they degrade instead of
truncating; everything else is allowed to reflow.

### Reduce Motion covers decorative motion only

Gated: the scan screen's two `repeatForever` animations (a sweeping line and a
spinning arc — continuous motion is exactly what the setting is for), the
press-scale button feedback, and the queued-confirmation spring. The stopped
spinner draws as a full ring rather than a frozen quarter-arc, which would read
as a rendering bug.

Not gated: the side menu, Settings accordion, swipe-row settle, and compact
header. These are brief and convey a state change rather than decorating one;
removing them would make the interface harder to follow, not calmer.

## Consequences

Verification is manual and easy to regress, since none of this is covered by
the test suite — `xcodebuild test` will not catch a missing label. The
verification steps live in `ios/README.md`; the ones that matter are a live
content-size change without relaunch, Reduce Motion on the scan screen, and a
VoiceOver pass over the catalog row and edit form.

`.appFont` being a view modifier rather than a `Font` value means it cannot be
passed where a `Font` is expected. Nothing needs that today, and `Font.app` was
removed rather than left as a shim; if some future call site genuinely needs a
`Font`, it will have to compute the scaled size itself and accept that it won't
update live.
