import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var editors: NativeEditors?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SchoolzipTabs") {
      editors = NativeEditors(messenger: registrar.messenger(), presenter: { registrar.viewController })
      registrar.register(WeekControlFactory(registrar.messenger()), withId: "schoolzip/week")
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

// Let UIKit own tab geometry, safe-area insets and the Liquid Glass background.
private final class SchoolTabs: UIView, FlutterPlatformView, UITabBarControllerDelegate {
  private let controller = UITabBarController()
  private let channel: FlutterMethodChannel
  init(frame: CGRect, channel: FlutterMethodChannel) {
    self.channel = channel
    super.init(frame: frame)
    controller.viewControllers = [("시간표", "calendar"), ("급식", "fork.knife"), ("설정", "gearshape")].enumerated().map { index, item in
      let page = UIViewController()
      page.view.backgroundColor = .clear
      page.tabBarItem = UITabBarItem(title: item.0, image: UIImage(systemName: item.1), tag: index)
      return page
    }
    controller.delegate = self
    controller.view.backgroundColor = .clear
    controller.tabBar.tintColor = .systemIndigo
    controller.view.frame = bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(controller.view)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard call.method == "select", let index = call.arguments as? Int,
            (0..<3).contains(index) else { reply(FlutterMethodNotImplemented); return }
      self?.controller.selectedIndex = index
      reply(nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  deinit { channel.setMethodCallHandler(nil) }
  func view() -> UIView { self }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      controller.willMove(toParent: nil)
      controller.removeFromParent()
    } else if controller.parent == nil {
      var responder: UIResponder? = next
      while let current = responder {
        if let parent = current as? UIViewController {
          parent.addChild(controller)
          controller.didMove(toParent: parent)
          break
        }
        responder = current.next
      }
    }
  }
  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    channel.invokeMethod("tap", arguments: tabBarController.selectedIndex)
  }
}

private final class WeekControlFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeWeekControl(frame: frame, selected: args as? Int ?? 0,
      channel: FlutterMethodChannel(name: "schoolzip/week/\(id)", binaryMessenger: messenger))
  }
}

private final class NativeWeekControl: NSObject, FlutterPlatformView {
  private let control = UISegmentedControl(items: ["이번 주", "다음 주"])
  private let channel: FlutterMethodChannel
  init(frame: CGRect, selected: Int, channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    control.frame = frame
    control.selectedSegmentIndex = selected
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard call.method == "select", let index = call.arguments as? Int,
            (0..<2).contains(index) else { reply(FlutterMethodNotImplemented); return }
      if self?.control.selectedSegmentIndex != index {
        self?.control.selectedSegmentIndex = index
      }
      reply(nil)
    }
  }
  deinit { channel.setMethodCallHandler(nil) }
  @objc private func changed() { channel.invokeMethod("change", arguments: control.selectedSegmentIndex) }
  func view() -> UIView { control }
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
    // The root settings title shares the content-header geometry of the other tabs.
    // Editors still use their own standard UINavigationController bars.
    navigation.setNavigationBarHidden(true, animated: false)
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
  private let titleLabel = UILabel()
  private let titleHeader = UIView()
  private var headerWidth: CGFloat = 0
  private var headerHeight: CGFloat = 0
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
      guard let self = self else { reply(nil); return }
      let previous = self.selection
      self.selection = selection
      if self.isViewLoaded {
        // Keep the existing UISwitch alive while its native touch animation finishes.
        for (row, key) in ["showTeachers", "highlightToday"].enumerated() {
          if let toggle = self.tableView.cellForRow(at: IndexPath(row: row, section: 1))?.accessoryView as? UISwitch {
            let value = selection[key] != "false"
            if toggle.isOn != value { toggle.setOn(value, animated: true) }
          }
        }
        var rows: [IndexPath] = []
        if previous["school"] != selection["school"] || previous["room"] != selection["room"] { rows.append(IndexPath(row: 0, section: 0)) }
        if previous["allergyCount"] != selection["allergyCount"] { rows.append(IndexPath(row: 0, section: 2)) }
        if !rows.isEmpty { self.tableView.reloadRows(at: rows, with: .none) }
      }
      reply(nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  deinit { channel.setMethodCallHandler(nil) }
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 44
    titleLabel.text = "설정"
    titleLabel.font = UIFont(descriptor: UIFont.preferredFont(forTextStyle: .largeTitle).fontDescriptor.withSymbolicTraits(.traitBold) ?? UIFont.preferredFont(forTextStyle: .largeTitle).fontDescriptor, size: 0)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.textColor = .label
    titleLabel.accessibilityTraits.insert(.header)
    titleHeader.addSubview(titleLabel)
    tableView.tableHeaderView = titleHeader
    tableView.contentInset.bottom = 90
    tableView.verticalScrollIndicatorInsets.bottom = 90
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let width = tableView.bounds.width
    let size = titleLabel.sizeThatFits(CGSize(width: max(0, width - 40), height: .greatestFiniteMagnitude))
    let height = 20 + size.height + 6
    titleLabel.frame = CGRect(x: 20, y: 20, width: max(0, width - 40), height: size.height)
    if width != headerWidth || height != headerHeight {
      headerWidth = width; headerHeight = height
      titleHeader.frame = CGRect(x: 0, y: 0, width: width, height: height)
      tableView.tableHeaderView = titleHeader
    }
  }
  override func numberOfSections(in tableView: UITableView) -> Int { headers.count }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 1 ? 3 : 1 }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { headers[section] }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: indexPath.section == 0 ? .value1 : .default, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
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
      toggle.isOn = selection[key] != "false"
      toggle.accessibilityLabel = content.text
      toggle.addAction(UIAction { [weak self, weak toggle] _ in
        guard let toggle = toggle else { return }
        self?.selection[key] = toggle.isOn ? "true" : "false"
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

private final class NativeEditors {
  let channel: FlutterMethodChannel
  let presenter: () -> UIViewController?
  init(messenger: FlutterBinaryMessenger, presenter: @escaping () -> UIViewController?) {
    self.presenter = presenter
    channel = FlutterMethodChannel(name: "schoolzip/editors", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self, let root = self.presenter() else {
        reply(FlutterError(code: "presenter", message: "화면을 열 수 없습니다", details: nil)); return
      }
      var parent = root
      while let shown = parent.presentedViewController { parent = shown }
      guard !parent.isBeingDismissed else { reply(nil); return }
      let args = call.arguments as? [String: Any] ?? [:]
      let page: UIViewController
      switch call.method {
      case "allergies":
        page = NativeAllergies(names: args["names"] as? [String] ?? [], selected: args["selected"] as? [Int] ?? [], finish: reply)
      case "teachers": page = NativeTeacherList(channel: self.channel, finish: reply)
      case "teacher":
        let editor = NativeTeacherEditor(entry: args as? [String: String] ?? [:])
        editor.saveValue = { value, completion in
          self.channel.invokeMethod("saveTeacher", arguments: ["value": value]) { result in
            if let error = result as? FlutterError { completion(error.message ?? "저장하지 못했어요"); return }
            completion(nil); reply(nil)
          }
        }
        editor.cancelValue = { reply(nil) }
        editor.standalone = true
        page = editor
      default: reply(FlutterMethodNotImplemented); return
      }
      let navigation = UINavigationController(rootViewController: page)
      navigation.navigationBar.prefersLargeTitles = false
      navigation.modalPresentationStyle = .pageSheet
      navigation.isModalInPresentation = true
      parent.present(navigation, animated: true)
    }
  }
}

private final class NativeAllergies: UITableViewController {
  let names: [String]
  var selected: Set<Int>
  let finish: FlutterResult
  init(names: [String], selected: [Int], finish: @escaping FlutterResult) {
    self.names = names; self.selected = Set(selected); self.finish = finish
    super.init(style: .insetGrouped)
    title = "내 알레르기"
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
  }
  @objc func cancel() { dismiss(animated: true) { self.finish(nil) } }
  @objc func save() { let values = selected.sorted(); dismiss(animated: true) { self.finish(values) } }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(0, names.count - 1) }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "급식에서 강조할 재료" }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let code = indexPath.row + 1
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration(); content.text = names[code]; cell.contentConfiguration = content
    let toggle = UISwitch(); toggle.isOn = selected.contains(code); toggle.accessibilityLabel = names[code]
    toggle.addAction(UIAction { [weak self, weak toggle] _ in
      guard let self = self, let toggle = toggle else { return }
      if toggle.isOn { self.selected.insert(code) } else { self.selected.remove(code) }
    }, for: .valueChanged)
    cell.accessoryView = toggle; cell.selectionStyle = .none
    return cell
  }
}

private final class NativeTeacherList: UITableViewController {
  let channel: FlutterMethodChannel
  let finish: FlutterResult
  var entries: [[String: String]] = []
  init(channel: FlutterMethodChannel, finish: @escaping FlutterResult) {
    self.channel = channel; self.finish = finish
    super.init(style: .insetGrouped); title = "선생님 이름 설정"
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
    load()
  }
  @objc func done() { dismiss(animated: true) { self.finish(nil) } }
  func load() {
    let spinner = UIActivityIndicatorView(style: .medium); spinner.startAnimating(); tableView.backgroundView = spinner
    channel.invokeMethod("loadTeachers", arguments: nil) { [weak self] result in
      guard let self = self else { return }
      self.tableView.backgroundView = nil
      guard let entries = result as? [[String: String]] else {
        let alert = UIAlertController(title: "선생님 목록을 불러오지 못했어요", message: "시간표 연결을 확인하고 다시 시도해 주세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in self?.load() })
        self.present(alert, animated: true); return
      }
      self.entries = entries; self.tableView.reloadData()
      if entries.isEmpty {
        let label = UILabel(); label.text = "등록된 선생님이 없어요"; label.textAlignment = .center; label.textColor = .secondaryLabel
        self.tableView.backgroundView = label
      }
    }
  }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let entry = entries[indexPath.row]
    let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration(); content.text = (entry["current"] ?? "") + " 선생님"; content.secondaryText = entry["subject"]
    cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let editor = NativeTeacherEditor(entry: entries[indexPath.row])
    editor.saveValue = { [weak self] value, completion in
      guard let self = self else { completion("화면이 닫혔습니다"); return }
      let entry = self.entries[indexPath.row]
      self.channel.invokeMethod("saveTeacher", arguments: ["key": entry["key"] ?? entry["subject"] ?? "", "subject": entry["subject"] ?? "", "original": entry["original"] ?? "", "value": value]) { result in
        if let error = result as? FlutterError { completion(error.message ?? "저장하지 못했어요"); return }
        let raw = entry["original"] ?? ""
        let fallback = !raw.contains("*") && raw.count == 2 ? raw + "*" : raw
        self.entries[indexPath.row]["current"] = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tableView.reloadRows(at: [indexPath], with: .none)
        completion(nil)
      }
    }
    navigationController?.pushViewController(editor, animated: true)
  }
}

private final class NativeTeacherEditor: UITableViewController, UITextFieldDelegate {
  let entry: [String: String]
  let input = UITextField()
  var standalone = false
  var saving = false
  var saveValue: ((String, @escaping (String?) -> Void) -> Void)?
  var cancelValue: (() -> Void)?
  init(entry: [String: String]) {
    self.entry = entry
    super.init(style: .insetGrouped); title = "선생님 표시 이름"
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    input.text = entry["current"]; input.placeholder = "표시할 이름"; input.font = .preferredFont(forTextStyle: .body)
    input.adjustsFontForContentSizeCategory = true; input.clearButtonMode = .whileEditing; input.returnKeyType = .done; input.delegate = self
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
    if standalone { navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)) }
  }
  override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); input.becomeFirstResponder() }
  @objc func cancel() { dismiss(animated: true) { self.cancelValue?() } }
  @objc func save() { commit(input.text ?? "") }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool { save(); return true }
  func commit(_ value: String) {
    guard !saving else { return }
    saving = true; input.isEnabled = false; navigationItem.rightBarButtonItem?.isEnabled = false
    saveValue?(value) { [weak self] error in
      guard let self = self else { return }
      self.saving = false; self.input.isEnabled = true; self.navigationItem.rightBarButtonItem?.isEnabled = true
      if let error = error {
        let alert = UIAlertController(title: "저장하지 못했어요", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default)); self.present(alert, animated: true); return
      }
      if self.standalone { self.dismiss(animated: true) }
      else { self.navigationController?.popViewController(animated: true) }
    }
  }
  override func numberOfSections(in tableView: UITableView) -> Int { 2 }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    section == 0 ? "\(entry["subject"] ?? "") · 컴시간 표시명 \(entry["original"] ?? "")" : nil
  }
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { section == 0 ? "현재 교사 명단에서 같은 선생님의 모든 과목에 적용돼요." : nil }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    if indexPath.section == 0 {
      input.translatesAutoresizingMaskIntoConstraints = false; cell.contentView.addSubview(input)
      let margins = cell.contentView.layoutMarginsGuide
      NSLayoutConstraint.activate([input.leadingAnchor.constraint(equalTo: margins.leadingAnchor), input.trailingAnchor.constraint(equalTo: margins.trailingAnchor), input.topAnchor.constraint(equalTo: margins.topAnchor), input.bottomAnchor.constraint(equalTo: margins.bottomAnchor), input.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)])
      cell.selectionStyle = .none
    } else {
      var content = cell.defaultContentConfiguration(); content.text = "컴시간 이름으로 복원"; content.textProperties.color = .systemBlue; cell.contentConfiguration = content
    }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 1 { commit("") }
  }
}
