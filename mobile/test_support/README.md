# Native scroll regression check

`native_scroll_app.dart` renders test-only timetable/meal content and the real settings and tab components. It does not read or reset saved preferences or contact the backend.

With an iPhone simulator booted, run from `mobile/`:

```sh
flutter build ios --simulator --target test_support/native_scroll_app.dart
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcodebuild test -project ios/ScrollUITests/ScrollTests.xcodeproj -scheme ScrollTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/schoolzip-scroll-tests
flutter build ios --release --config-only --target lib/main.dart
```

The UI test sends real UIKit touch events. It checks the initial large title, collapse after scrolling, full restoration after scrolling back, native school-change action, Flutter content taps, and all three tabs. Collapsed and restored screenshots are attached to the Xcode test result. Restore `lib/main.dart` as the build target before making a production build.
