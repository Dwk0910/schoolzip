# schoolzip

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS home screens

The iOS home surface is `schoolzip/main-tabs`, a platform view implemented by
`MainTabsHost` in `ios/Runner/AppDelegate.swift`. It contains a real
`UITabBarController` with three `UINavigationController` children. Timetable,
meals, and settings render their content in native `UITableViewController`s;
UIKit owns their scrolling, large titles, scroll-edge effects, and tab transitions.

`lib/native_home.dart` sends data and actions over `schoolzip/home`. The offstage
Dart pages retain fetching, cached timetable data, teacher aliases, selections,
and existing dialogs, but do not render or scroll the iOS home content. Android
continues to use the Flutter screens. `overviewGrid` builds the shared timetable
model so both renderers use the same class/teacher selection rules.

Do not synchronize a second Flutter scroll position with the native title or put
empty native controllers in front of Flutter tab bodies: both approaches separate
the title/transition from the visible content. Native scroll and selector UI
regression checks are documented in [test_support](test_support/README.md).
