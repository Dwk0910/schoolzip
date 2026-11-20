# Native scroll regression check

`native_scroll_app.dart` renders test-only timetable content and the real meal, settings, and tab components. The real meal page receives an empty local response. It does not read or reset saved preferences or contact the backend.

With an iPhone simulator booted, run from `mobile/`:

```sh
flutter build ios --simulator --target test_support/native_scroll_app.dart
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcodebuild test -project ios/ScrollUITests/ScrollTests.xcodeproj -scheme ScrollTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/schoolzip-scroll-tests
flutter build ios --release --config-only --target lib/main.dart
```

The UI test sends real UIKit touch events. It checks the initial large title, collapse after scrolling, full restoration after scrolling back, native school-change and content actions, Flutter selector presentation above native screens, and all three tabs. On the short meal page it checks the restored illustration, compact date control, calendar presentation, and restoration after a native bounce. Collapsed and restored screenshots are attached to the Xcode test result. Restore `lib/main.dart` as the build target before making a production build.

Also inspect the production target in Device Hub (`com.apple.dt.Devices`; Xcode
27 installs it in `Xcode.app/Contents/Applications/DeviceHub.app`). Use the actual
school data as well as the deterministic long-table fixture:

- Inspect the entire first character of the school subtitle at the top of both pages.
- Drag starting on lesson cells, not only in the outer margin. Check an ordinary
  seven-period week and a long table; short content should retain native bounce.
- In class view choose a date with lessons, swipe horizontally to the last class,
  then drag vertically from inside the same grid.
- Open the meal calendar, select a date, and check the compact shared date control
  and original empty-tray illustration. The calendar applies a day immediately;
  it does not have a Cancel button.

Native title/frame assertions alone do not detect rounded-cell clipping or lost
illustrations. Review the captured screenshots before installing a device build.
