import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SchoolzipTabs") {
      registrar.register(SettingsFactory(registrar.messenger()), withId: "schoolzip/settings")
      registrar.register(SchoolTabsFactory(registrar.messenger()), withId: "schoolzip/tabs")
    }
    let channel = FlutterMethodChannel(name: "schoolzip/today", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard let config = call.arguments as? [String:String] else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let store = UserDefaults(suiteName: "group.app.schoolzip.schoolzip") else {
        result(FlutterError(code:"app_group",message:"Widget storage unavailable",details:nil))
        return
      }
      switch call.method {
      case "reset":
        store.removePersistentDomain(forName: "group.app.schoolzip.schoolzip")
      case "configure":
        store.set(config, forKey: "class")
      case "teacherNames":
        guard let code = config["code"], let names = config["names"] else {
          result(FlutterError(code: "teacher_names", message: "Missing teacher names", details: nil))
          return
        }
        let key = "teacherNames.\(code)"
        if (store.string(forKey: key) ?? "{}") == names {
          result(nil)
          return
        }
        store.set(names, forKey: key)
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      WidgetCenter.shared.reloadTimelines(ofKind:"SchoolzipToday")
      result(nil)
    }
  }
}

private final class SchoolTabsFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    SchoolTabs(frame: frame, channel: FlutterMethodChannel(name: "schoolzip/tabs/\(id)", binaryMessenger: messenger))
  }
}

private final class SchoolTabs: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let container = UIView()
  private let bar: UITabBar
  private let channel: FlutterMethodChannel
  init(frame: CGRect, channel: FlutterMethodChannel) {
    self.channel = channel
    bar = UITabBar(frame: frame)
    super.init()
    container.frame = frame
    var sideInset: CGFloat = 0
    var verticalInset: CGFloat = 0
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      sideInset = 16
      verticalInset = 3
      let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
      glass.translatesAutoresizingMaskIntoConstraints = false
      glass.layer.cornerRadius = 28
      glass.clipsToBounds = true
      container.addSubview(glass)
      let appearance = UITabBarAppearance()
      appearance.configureWithTransparentBackground()
      bar.standardAppearance = appearance
      bar.scrollEdgeAppearance = appearance
      NSLayoutConstraint.activate([
        glass.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: sideInset),
        glass.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -sideInset),
        glass.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalInset),
        glass.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalInset)
      ])
    }
    #endif
    container.addSubview(bar)
    bar.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      bar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: sideInset),
      bar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -sideInset),
      bar.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalInset),
      bar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalInset)
    ])
    bar.tintColor = .systemIndigo
    bar.items = [
      UITabBarItem(title: "시간표", image: UIImage(systemName: "calendar"), tag: 0),
      UITabBarItem(title: "급식", image: UIImage(systemName: "fork.knife"), tag: 1),
      UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape"), tag: 2)
    ]
    bar.selectedItem = bar.items?.first
    bar.delegate = self
    channel.setMethodCallHandler { [weak self] call, reply in
      guard call.method == "select", let index = call.arguments as? Int,
            let items = self?.bar.items, items.indices.contains(index) else {
        reply(FlutterMethodNotImplemented)
        return
      }
      self?.bar.selectedItem = items[index]
      reply(nil)
    }
  }
  func view() -> UIView { container }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("tap", arguments: item.tag)
  }
}

private final class SettingsFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    let channel = FlutterMethodChannel(name: "schoolzip/settings/\(id)", binaryMessenger: messenger)
    return SettingsHost(frame: frame, controller: SettingsTable(args as? [String:String] ?? [:], channel))
  }
}

private final class SettingsHost: UIView, FlutterPlatformView {
  let navigation: UINavigationController
  init(frame: CGRect, controller: SettingsTable) {
    navigation = UINavigationController(rootViewController: controller)
    super.init(frame: frame)
    navigation.navigationBar.prefersLargeTitles = true
    navigation.view.frame = bounds
    navigation.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(navigation.view)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  func view() -> UIView { self }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      navigation.willMove(toParent: nil)
      navigation.removeFromParent()
    } else if navigation.parent == nil {
      var ancestor: UIResponder? = next
      while let responder = ancestor {
        if let parent = responder as? UIViewController {
          parent.addChild(navigation)
          navigation.didMove(toParent: parent)
          break
        }
        ancestor = responder.next
      }
    }
  }
}

private final class SettingsTable: UITableViewController {
  private var selection: [String:String]
  private let channel: FlutterMethodChannel
  private let headers = ["학교 설정", "시간표", "급식", "데이터 관리"]
  init(_ selection: [String:String], _ channel: FlutterMethodChannel) {
    self.selection = selection
    self.channel = channel
    super.init(style: .insetGrouped)
    title = "설정"
    channel.setMethodCallHandler { [weak self] call, reply in
      guard call.method == "update", let selection = call.arguments as? [String:String] else {
        reply(FlutterMethodNotImplemented)
        return
      }
      self?.selection = selection
      if self?.isViewLoaded == true { self?.tableView.reloadData() }
      reply(nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  deinit { channel.setMethodCallHandler(nil) }
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    max(44, UIFont.preferredFont(forTextStyle: .body).lineHeight + 16)
  }
  override func numberOfSections(in tableView: UITableView) -> Int { headers.count }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 1 ? 3 : 1 }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { headers[section] }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: indexPath.section == 0 ? .value1 : .default, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
    content.directionalLayoutMargins.leading = 14
    content.directionalLayoutMargins.trailing = 14
    switch indexPath.section {
    case 0:
      content.text = "학교 바꾸기"
      content.secondaryText = [selection["school"], selection["room"]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
      content.secondaryTextProperties.color = .secondaryLabel
    case 1: content.text = ["선생님 이름 표시","오늘 열 강조","선생님 이름 설정"][indexPath.row]
    case 2:
      content.text = "내 알레르기"
      let count = selection["allergyCount"] ?? "0"
      content.secondaryText = count == "0" ? "선택 안 함" : "\(count)개 선택"
    default:
      content.text = "전체 초기화"
      content.textProperties.color = .systemRed
    }
    cell.contentConfiguration = content
    cell.accessoryType = indexPath.section == 3 ? .none : .disclosureIndicator
    if indexPath.section == 1 && indexPath.row < 2 {
      let key = indexPath.row == 0 ? "showTeachers" : "highlightToday"
      let toggle = UISwitch()
      toggle.onTintColor = UIColor(red: 49/255, green: 130/255, blue: 246/255, alpha: 1)
      toggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
      toggle.isOn = selection[key] != "false"
      toggle.accessibilityLabel = content.text
      toggle.addAction(UIAction { [weak self, weak toggle] _ in
        guard let toggle = toggle else { return }
        self?.channel.invokeMethod(key, arguments: toggle.isOn)
      }, for: .valueChanged)
      cell.accessoryView = toggle
      cell.selectionStyle = .none
    }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 1 && indexPath.row < 2 { return }
    channel.invokeMethod(["school","teachers","allergies","reset"][indexPath.section], arguments: nil)
  }
}
