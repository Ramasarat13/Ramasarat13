# Swimy

**Understand every swim.** A native iPhone app that turns Apple Health swim workouts
into plain-language insights, progress over time and shareable cards. No account,
no servers: everything stays on the iPhone.

SwiftUI · iOS 26 · Swift 6 · no third-party packages.

## Open and run

You need a Mac with **Xcode 26** or later.

1. Double-click `Swimy.xcodeproj` to open it in Xcode.
2. At the top of the Xcode window, pick the **Swimy** scheme and an iPhone simulator
   (for example *iPhone 17*).
3. Press **⌘R**. The app opens with 30 sample swims.

Run the unit tests with **⌘U**.

**Try the edge cases:** tap the profile button (top right) → *Developer* → *Mock data*,
then choose *Only 1 swim* or *No swims*. This menu only exists in debug builds.

**On your own iPhone:** click the blue *Swimy* project in the left sidebar → *Swimy*
target → *Signing & Capabilities* → pick your *Team* (a free Apple ID works). If Xcode
says the bundle identifier is taken, change `com.ramasarat.Swimy` to something unique.

## Build progress

The spec says to build one phase at a time. This is **Phase 1: Foundation**.

- [x] Xcode project, folder structure, app icon (placeholder)
- [x] Design tokens: colours (light + dark), type, spacing, motion, haptics
- [x] Components: `MetricCard`, `ComparisonChip`, `SwimRow`, mini charts, `LanesView`,
      `PoolTileView`, `InfoSheet`, empty state
- [x] Tab bar (Summary, Activity, Insights) + Profile sheet on every tab
- [x] `MockSwimProvider`: 30 realistic swims (25 m, 50 m and 25 yd pools, open water,
      missing heart rate, a third-party swim, a very short swim)
- [x] "Compared with your usual" maths, unit rules and formatting, with unit tests
- [ ] Phase 2: Apple Health, SwiftData cache, background sync
- [ ] Phase 3: full Summary and Swim Detail (range menu, charts, strokes, sets, ⓘ copy)
- [ ] Phase 4: Activity calendar and filters, Profile stats and animated pool tile
- [ ] Phase 5: Insights · Phase 6: Share composer · Phase 7: onboarding, motion, VoiceOver pass

## Where things live

```
Swimy/
  App/            App entry, tab bar, navigation, Profile button, preview helpers
  DesignSystem/   Colours, text styles, spacing, motion, haptics
  Components/     Reusable views: MetricCard, ComparisonChip, SwimRow, PoolTileView…
  Features/       One folder per screen: Summary, SwimDetail, Activity, Insights, Profile
  Stores/         Shared app state: SwimStore (swims), SettingsStore (settings)
  Services/       Pure logic: MetricsEngine (your usual), SwimFormatter (units, text)
  Data/           Swim models, the data-provider protocol and the mock provider
  Resources/      Assets.xcassets: app icon and colour sets
SwimyTests/       Unit tests (Swift Testing)
```

**To change a colour:** open `Resources/Assets.xcassets`, pick a colour set such as
`MetricPace`, and edit its *Any* (light) and *Dark* values in the inspector.

## Design decisions to review

These follow the spec's principles and accessibility rules; change any you disagree with.

| Decision | Why |
| --- | --- |
| Metric colours slightly adjusted: heart `#E5605A`, distance `#23A07A` (light) | The spec values fell under 3:1 contrast on white cards. All four pass colour-blind checks in both modes. |
| Dark-mode variants added for every colour | The spec lists dark mode as not yet designed. |
| Values and labels are black/grey text; icons and charts carry the metric colour | Coloured caption text can't reach 4.5:1 contrast. |
| "Better than usual" green is `#1A7F37` in light mode | System green is too light for small chip text. |
| Lifetime tile text is white on a dark gradient | The spec flagged the light-blue "LIFETIME" label as failing contrast. |
| Chip arrow shows which way the number moved; green means better | So "▼ 6% vs usual" in green reads as "faster" for pace. VoiceOver says "6 percent faster than usual". |
| A single pool swim's distance uses the pool's unit (1,500 m / 1,000 yd) | Matches Apple Fitness. Totals use km or mi. |
| `StrokeStyle` is named `SwimStroke` in code | SwiftUI already has a type called `StrokeStyle`. |

## Notes for later phases

- Swift 6 language mode with complete concurrency checking. Stores are `@MainActor`,
  models are `Sendable` structs, services are pure `enum`s with static functions.
- Views never talk to HealthKit. They read `SwimStore`, which reads a `SwimDataProvider`.
  Phase 2 adds `HealthKitSwimProvider` next to `MockSwimProvider`.
- Colour sets generate Swift names automatically (`MetricPace` → `Color.metricPace`),
  so don't also declare those names in code.
- Folders are Xcode "synchronized" groups: new files in `Swimy/` or `SwimyTests/`
  join the right target automatically. File names must be unique across the target.
