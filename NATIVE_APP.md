# Native Event Forecast

Open `EventForecast.xcodeproj`, choose the `EventForecast` scheme and an iPhone Simulator, then Run. The app targets iOS 17 or later. The React files remain a separate prototype.

The Native iOS checks workflow tests the model, builds the Simulator and iPhone targets, and publishes an `EventForecast-Simulator` artifact. Download and unzip both archive layers, then drag `EventForecast.app` onto a booted iPhone Simulator. This artifact runs in Simulator. A physical iPhone needs a signed build from Xcode or a separate distribution setup.

## Resize behavior

Drag the middle handle down to enlarge charts or up to make room for inputs. The handle follows the finger in a fixed coordinate space. One height drives both the drag and the release spring, so releasing no longer resets the offset before snapping.

Four stops remain: More input space, Balanced, Larger charts, and Full charts. A short flick has limited travel. Tap the handle to step through the stops; in Full charts, tap to return to Larger charts. A chosen input/chart split stays in place when changing editor sections. The divider has a 44-point touch area, VoiceOver adjustment actions, and named actions for the two ends.

The divider stays still at rest. Chart details fade in as space grows, without the former delayed hide/reveal tasks. Reduce Motion disables automatic animation throughout the app while direct dragging remains available.

## State and calculations

`ForecastModel` owns values, derived results, and undo history. `ForecastLibrary` stores named snapshots. The view owns navigation, the chosen editor, and transient resize state. `WorkspaceLayout` holds geometry and snapping rules without importing SwiftUI.

Budget totals and itemization are separate by design: editing an item changes its reconciliation gap, not the chosen budget total. Saved ledger order and names remain in each snapshot.

The review fixes these edge cases:

- Other revenue can cover break-even or a profit target even with free tickets and no attendance. Those thresholds now return zero instead of “not reachable.”
- Extremely small ticket prices no longer overflow the integer ticket-count conversion.
- Selecting, restoring, or undoing an event scale preserves that scale.
- Manual-save name edits wait for Save. Auto-save uses the current working name rather than replacing it with the old saved name.
- Itemized controls expose meaningful labels and accessible reorder actions.
- The compact pie chart keeps its original width in a square frame. The summary reserves enough height for the whole chart rather than clipping or shrinking it. Compact input spacing also keeps the final slider clear of the bottom bar.

## Verification

Run the platform-independent regression suite on a Mac with Xcode:

```sh
swift test --scratch-path /tmp/EventForecastTests
```

Build the app without signing:

```sh
xcodebuild -project EventForecast.xcodeproj -scheme EventForecast \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/EventForecastBuild CODE_SIGNING_ALLOWED=NO build
```

The suite covers financial thresholds, itemization, undo/redo, save behavior, scale restoration, persistence, ordered resize stops, bounds, and flick projection. iPhone 16 Pro and iPhone SE Simulator checks cover drag/release in both directions, tap stops, chart/editor navigation, and compact chart/input bounds. Named accessibility actions, ledger reorder/Undo, and the system Reduce Motion setting were also checked. These checks do not establish device frame rates.

## Apple references

- [Drag gesture coordinate spaces](https://developer.apple.com/documentation/swiftui/draggesture/coordinatespace)
- [Animate with springs, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/)
- [Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- [Accessibility adjustable actions](https://developer.apple.com/documentation/swiftui/view/accessibilityadjustableaction(_:))
- [Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)

The performance review found an idle repeating path animation, repeated delayed chart reveals, and conflicting drag/reset state. The fixes remove those sources of work. No device Instruments trace or FPS improvement is claimed.
