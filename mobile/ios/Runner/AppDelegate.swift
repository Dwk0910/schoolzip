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
      registrar.register(MainTabsFactory(registrar.messenger()), withId: "schoolzip/main-tabs")
      registrar.register(WeekControlFactory(registrar.messenger()), withId: "schoolzip/week")
      registrar.register(SettingsFactory(registrar.messenger()), withId: "schoolzip/settings")
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
    navigation.navigationBar.prefersLargeTitles = true
    controller.navigationItem.largeTitleDisplayMode = .always
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
  var bottomPadding: CGFloat = 90
  private var selection: [String:String]
  private let channel: FlutterMethodChannel
  private let headers = ["학교 설정", "시간표", "급식", "기타"]
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
        if previous["startup"] != selection["startup"] { rows.append(IndexPath(row: 2, section: 1)) }
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
    tableView.contentInset.bottom = bottomPadding
    tableView.verticalScrollIndicatorInsets.bottom = bottomPadding
  }
  override func numberOfSections(in tableView: UITableView) -> Int { headers.count }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 1 ? 4 : section == 3 ? 2 : 1 }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { headers[section] }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: indexPath.section == 0 || (indexPath.section == 1 && indexPath.row == 2) ? .value1 : .default, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
    switch indexPath.section {
    case 0:
      content.text = "학교 바꾸기"
      content.secondaryText = [selection["school"], selection["room"]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
      content.secondaryTextProperties.color = .secondaryLabel
    case 1:
      content.text = ["선생님 이름 표시","오늘 열 강조","앱 시작 시 시간표","선생님 이름 설정"][indexPath.row]
      if indexPath.row == 2 { content.secondaryText = selection["startup"] ?? "요일별 보기"; content.secondaryTextProperties.color = .secondaryLabel }
    case 2:
      content.text = "내 알레르기"
      let count = selection["allergyCount"] ?? "0"
      content.secondaryText = count == "0" ? "선택 안 함" : "\(count)개 선택"
    default:
      content.text = indexPath.row == 0 ? "사용 안내 다시 보기" : "전체 초기화"
      content.textProperties.color = indexPath.row == 0 ? .systemBlue : .systemRed
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
    if indexPath.section == 1 && indexPath.row == 2 { channel.invokeMethod("startup", arguments: nil); return }
    let action = indexPath.section == 3 ? (indexPath.row == 0 ? "guide" : "reset") : ["school","teachers","allergies"][indexPath.section]
    channel.invokeMethod(action, arguments: nil)
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
      case "startupTimetable":
        page = NativeStartupTimetable(args: args, finish: reply)
      case "reviewTeacherNames":
        page = NativeTeacherReview(options: args["options"] as? [[String:String]] ?? [], title: args["title"] as? String ?? "이름 확인", loader: (args["loader"] as? String).map { FlutterMethodChannel(name: $0, binaryMessenger: messenger) }, finish: reply)
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
  override func numberOfSections(in tableView: UITableView) -> Int { 2 }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 2 : entries.count }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    section == 1 ? "이름 직접 수정" : nil
  }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      var content = cell.defaultContentConfiguration()
      content.text = indexPath.row == 0 ? "학교 공유 이름 불러오기" : "이전 명단 이름 연결하기"
      content.textProperties.color = .systemBlue; cell.contentConfiguration = content
      return cell
    }
    let entry = entries[indexPath.row]
    let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration(); content.text = (entry["current"] ?? "") + " 선생님"; content.secondaryText = entry["subject"]
    cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 0 {
      channel.invokeMethod(indexPath.row == 0 ? "reviewShared" : "reviewPrevious", arguments: nil) { [weak self] result in
        if let error = result as? FlutterError {
          let alert = UIAlertController(title: "불러오지 못했어요", message: error.message, preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "확인", style: .default)); self?.present(alert, animated: true)
        }
        self?.load()
      }
      return
    }
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
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { section == 0 ? "같은 선생님의 모든 과목에 적용되며, 학교 공유 이름 후보로 자동 저장돼요." : nil }
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
private final class NativeTeacherReview: UITableViewController, UISearchResultsUpdating {
  var options: [[String:String]]
  let loader: FlutterMethodChannel?
  var loading: Bool
  var started = false
  var closed = false
  var loadFailed = false
  let finish: FlutterResult
  var selected = Set<Int>()
  var visible: [Int] = []
  var bulk: Set<Int> {
    let keys = Dictionary(grouping: options.indices, by: { options[$0]["key"] ?? "" })
    let sources = Dictionary(grouping: options.indices, by: { options[$0]["source"] ?? "" })
    return Set(options.indices.filter { keys[options[$0]["key"] ?? ""]?.count == 1 && sources[options[$0]["source"] ?? ""]?.count == 1 })
  }
  var bulkSelected: Bool { !selected.isEmpty && bulk.isSubset(of: selected) }
  let search = UISearchController(searchResultsController: nil)
  init(options: [[String:String]], title: String, loader: FlutterMethodChannel?, finish: @escaping FlutterResult) {
    self.options = options; self.finish = finish; self.loader = loader; self.loading = loader != nil
    super.init(style: .insetGrouped); self.title = title; visible = Array(options.indices)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    search.searchResultsUpdater = self; search.obscuresBackgroundDuringPresentation = false
    search.searchBar.placeholder = "이름 또는 과목 검색"; navigationItem.searchController = search
    navigationItem.hidesSearchBarWhenScrolling = false
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "선택 적용", style: .done, target: self, action: #selector(apply))
    navigationItem.rightBarButtonItem?.isEnabled = false
    updateLoading()
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !started && loader != nil { started = true; load() }
  }
  @objc private func load() {
    guard let loader = loader, !closed else { return }
    loading = true; loadFailed = false; updateLoading()
    loader.invokeMethod("load", arguments: nil) { [weak self] result in
      guard let self = self, !self.closed else { return }
      self.loading = false
      if let values = result as? [[String:String]] {
        self.options = values; self.visible = Array(values.indices)
      } else { self.loadFailed = true }
      self.updateLoading()
    }
  }
  private func updateLoading() {
    navigationItem.searchController = loading || loadFailed ? nil : search
    if loading || loadFailed {
      let background = UIView(); let stack = UIStackView(); stack.axis = .vertical; stack.alignment = .center; stack.spacing = 12
      if loading { let spinner = UIActivityIndicatorView(style: .medium); spinner.startAnimating(); stack.addArrangedSubview(spinner) }
      let label = UILabel(); label.text = loading ? "이름을 불러오는 중이에요." : "이름을 불러오지 못했어요."; label.font = .preferredFont(forTextStyle: .body); label.textColor = .secondaryLabel
      stack.addArrangedSubview(label)
      if loadFailed { let retry = UIButton(type: .system); retry.setTitle("다시 시도", for: .normal); retry.addTarget(self, action: #selector(load), for: .touchUpInside); stack.addArrangedSubview(retry) }
      background.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: background.centerXAnchor), stack.centerYAnchor.constraint(equalTo: background.centerYAnchor)])
      tableView.backgroundView = background
    } else { tableView.backgroundView = nil }
    tableView.reloadData()
  }
  @objc func cancel() { closed = true; dismiss(animated: true) { self.finish(nil) } }
  @objc func apply() {
    closed = true
    let values = selected.sorted().map { options[$0] }
    dismiss(animated: true) { self.finish(values) }
  }
  func updateSearchResults(for searchController: UISearchController) {
    let query = searchController.searchBar.text ?? ""
    visible = options.indices.filter { query.isEmpty || (options[$0]["title"]! + options[$0]["detail"]!).localizedCaseInsensitiveContains(query) }
    tableView.reloadData()
  }
  override func numberOfSections(in tableView: UITableView) -> Int { loading || loadFailed ? 0 : 2 }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 { return nil }
    return options.isEmpty ? "적용할 후보가 없습니다." : "이름과 과목을 확인해 선택해 주세요. 기존 이름은 덮어쓰지 않아요. 중복 후보는 전체 선택에서 제외되니 직접 골라 주세요."
  }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : visible.count }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      var content = cell.defaultContentConfiguration(); content.text = bulkSelected ? "전체 해제" : "전체 선택"
      content.textProperties.color = bulk.isEmpty && selected.isEmpty ? .tertiaryLabel : .systemBlue
      cell.contentConfiguration = content; return cell
    }
    let index = visible[indexPath.row]; let entry = options[index]
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration(); content.text = entry["title"]; content.secondaryText = entry["detail"]
    content.textProperties.numberOfLines = 0; content.secondaryTextProperties.numberOfLines = 0
    cell.contentConfiguration = content; cell.accessoryType = selected.contains(index) ? .checkmark : .none
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 0 {
      if bulkSelected { selected.removeAll() } else { selected.formUnion(bulk) }
      navigationItem.rightBarButtonItem?.isEnabled = !selected.isEmpty
      tableView.reloadData(); return
    }
    let index = visible[indexPath.row]
    if selected.contains(index) { selected.remove(index) }
    else {
      selected = selected.filter { options[$0]["key"] != options[index]["key"] && options[$0]["source"] != options[index]["source"] }
      selected.insert(index)
    }
    navigationItem.rightBarButtonItem?.isEnabled = !selected.isEmpty
    tableView.reloadData()
  }
}

// Complete UIKit screens: real tab children and one native vertical scroll view per page.
private final class MainTabsFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    MainTabsHost(frame: frame, messenger: messenger)
  }
}

private final class MainTabsHost: UIView, FlutterPlatformView, UITabBarControllerDelegate {
  private let tabs = UITabBarController()
  private let channel: FlutterMethodChannel
  private let timetable: SchoolContentTable
  private let meals: SchoolContentTable
  init(frame: CGRect, messenger: FlutterBinaryMessenger) {
    let bridge = FlutterMethodChannel(name: "schoolzip/home", binaryMessenger: messenger)
    channel = bridge
    timetable = SchoolContentTable(page: "timetable", title: "주간 시간표", channel: bridge)
    meals = SchoolContentTable(page: "meals", title: "급식 식단표", channel: bridge)
    let settings = SettingsTable([:], FlutterMethodChannel(name: "schoolzip/home/settings", binaryMessenger: messenger))
    settings.bottomPadding = 0
    super.init(frame: frame)
    let pages: [(UIViewController, String, String)] = [(timetable, "시간표", "calendar"), (meals, "급식", "fork.knife"), (settings, "설정", "gearshape")]
    tabs.viewControllers = pages.enumerated().map { index, value in
      let nav = UINavigationController(rootViewController: value.0)
      nav.navigationBar.prefersLargeTitles = true
      nav.navigationBar.tintColor = .systemIndigo
      value.0.navigationItem.largeTitleDisplayMode = .always
      nav.tabBarItem = UITabBarItem(title: value.1, image: UIImage(systemName: value.2), tag: index)
      return nav
    }
    tabs.delegate = self
    tabs.tabBar.tintColor = .systemIndigo
    tabs.view.frame = bounds
    tabs.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(tabs.view)
    bridge.setMethodCallHandler { [weak self] call, reply in
      guard let self = self, call.method == "update", let args = call.arguments as? [String:Any],
            let page = args["page"] as? String, let model = args["model"] as? [String:Any] else {
        reply(FlutterMethodNotImplemented); return
      }
      switch page {
      case "tabs":
        if let index = model["index"] as? Int, (0..<3).contains(index), index != self.tabs.selectedIndex { self.tabs.selectedIndex = index }
      case "timetable": self.timetable.update(model)
      case "meals": self.meals.update(model)
      default: break
      }
      reply(nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  deinit { channel.setMethodCallHandler(nil) }
  func view() -> UIView { self }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      tabs.willMove(toParent: nil); tabs.removeFromParent()
    } else if tabs.parent == nil {
      var nextResponder: UIResponder? = next
      while let responder = nextResponder {
        if let parent = responder as? UIViewController {
          parent.addChild(tabs); tabs.didMove(toParent: parent)
          channel.invokeMethod("ready", arguments: nil)
          break
        }
        nextResponder = responder.next
      }
    }
  }
  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    channel.invokeMethod("event", arguments: ["page":"tabs", "action":"select", "value":tabBarController.selectedIndex])
  }
}

private final class SchoolContentTable: UITableViewController {
  private let page: String
  private let channel: FlutterMethodChannel
  private var model: [String:Any] = [:]
  private let week = UISegmentedControl(items: ["이번 주", "다음 주"])
  private var horizontalOffset: CGFloat = 0
  private weak var gridScroll: UIScrollView?
  init(page: String, title: String, channel: FlutterMethodChannel) {
    self.page = page; self.channel = channel
    super.init(style: .plain)
    self.title = title
    week.addTarget(self, action: #selector(weekChanged), for: .valueChanged)
    if page == "timetable" {
      navigationItem.rightBarButtonItem = UIBarButtonItem(title: "학교 바꾸기", style: .plain, target: self, action: #selector(school))
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = .systemGroupedBackground
    tableView.separatorStyle = .none
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 400
    tableView.alwaysBounceVertical = true
    tableView.contentInset.bottom = 12
    tableView.sectionHeaderHeight = 0
    tableView.sectionFooterHeight = 0
  }
  func update(_ value: [String:Any]) {
    horizontalOffset = gridScroll?.contentOffset.x ?? horizontalOffset
    model = value
    if isViewLoaded { tableView.reloadData() }
  }
  private func emit(_ action: String, _ value: Any? = nil) {
    var event: [String:Any] = ["page":page, "action":action]
    if let value = value { event["value"] = value }
    channel.invokeMethod("event", arguments: event)
  }
  @objc private func school() { emit("school") }
  @objc private func weekChanged() { emit("week", week.selectedSegmentIndex) }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.backgroundColor = .clear
    cell.selectionStyle = .none
    let content = stack(spacing: 12)
    content.addArrangedSubview(label(model["subtitle"] as? String ?? "", size: 17, color: .secondaryLabel))
    if page == "timetable" { addTimetable(to: content) } else { addMeals(to: content) }
    cell.contentView.addSubview(content); content.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
      content.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
      content.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
      content.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
    ])
    return cell
  }
  private func stack(axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 0) -> UIStackView {
    let value = UIStackView(); value.axis = axis; value.spacing = spacing; return value
  }
  private func label(_ text: String, size: CGFloat = 17, weight: UIFont.Weight = .regular, color: UIColor = .label, centered: Bool = false) -> UILabel {
    let value = UILabel(); value.text = text; value.numberOfLines = 0
    value.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size, weight: weight))
    value.adjustsFontForContentSizeCategory = true; value.textColor = color
    value.textAlignment = centered ? .center : .natural
    return value
  }
  private func pin(_ child: UIView, to parent: UIView, inset: CGFloat = 0) {
    parent.addSubview(child); child.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset), child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset), child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset), child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)])
  }
  private func button(_ title: String, action: String, symbol: String? = nil) -> UIButton {
    var config = UIButton.Configuration.filled()
    config.title = title; config.baseBackgroundColor = .secondarySystemGroupedBackground
    config.baseForegroundColor = .label; config.cornerStyle = .fixed
    config.background.cornerRadius = 20
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
      var attributes = attributes
      attributes.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .semibold))
      return attributes
    }
    config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    config.titleLineBreakMode = .byTruncatingTail
    if let symbol = symbol { config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))?.withTintColor(.systemIndigo, renderingMode: .alwaysOriginal); config.imagePlacement = .trailing; config.imagePadding = 8 }
    let value = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.emit(action) })
    value.accessibilityLabel = title
    return value
  }
  private func addTimetable(to content: UIStackView) {
    let controls = stack(axis: .horizontal, spacing: 8); controls.distribution = .fillEqually
    controls.addArrangedSubview(button(model["mode"] as? String ?? "요일별 보기", action: "mode", symbol: "chevron.down"))
    controls.addArrangedSubview(button(model["context"] as? String ?? "선택", action: "context", symbol: "chevron.down"))
    content.addArrangedSubview(controls)
    if model["showWeek"] as? Bool ?? true {
      let index = model["week"] as? Int ?? 0
      if week.selectedSegmentIndex != index { week.selectedSegmentIndex = index }
      content.addArrangedSubview(week)
    }
    if let updated = model["updated"] as? String, !updated.isEmpty {
      content.addArrangedSubview(label("컴시간 갱신 · \(updated)", size: 13, color: .secondaryLabel))
    }
    if model["offline"] as? Bool == true { content.addArrangedSubview(button("저장된 시간표 · 다시 불러오기", action: "retry")) }
    switch model["status"] as? String {
    case "ready": content.addArrangedSubview(makeGrid())
    case "empty": content.addArrangedSubview(result("등록된 수업이 없어요", detail: "다른 날짜나 보기를 선택해 주세요.", symbol: "calendar"))
    case "error": content.addArrangedSubview(result("시간표를 불러오지 못했어요", detail: "잠시 후 다시 시도해 주세요.", symbol: "calendar.badge.exclamationmark")); content.addArrangedSubview(button("다시 시도", action: "retry"))
    default: content.addArrangedSubview(loading())
    }
  }
  private func loading() -> UIView {
    let spinner = UIActivityIndicatorView(style: .medium); spinner.startAnimating()
    spinner.heightAnchor.constraint(equalToConstant: 90).isActive = true
    return spinner
  }
  private func result(_ title: String, detail: String, symbol: String) -> UIView {
    let body = stack(spacing: 10)
    let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)))
    icon.tintColor = .systemIndigo; icon.contentMode = .scaleAspectFit
    icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
    body.addArrangedSubview(icon)
    body.addArrangedSubview(label(title, size: 21, weight: .bold, centered: true))
    body.addArrangedSubview(label(detail, size: 15, color: .secondaryLabel, centered: true))
    let box = UIView(); pin(body, to: box, inset: 24); return box
  }
  private func makeGrid() -> UIView {
    let columns = model["columns"] as? [[String:Any]] ?? []
    guard !columns.isEmpty else { return UIView() }
    let periods = model["periods"] as? Int ?? 0
    var cells: [String:[[String:Any]]] = [:]
    for cell in model["cells"] as? [[String:Any]] ?? [] {
      cells["\(cell["column"] as? Int ?? 0):\(cell["period"] as? Int ?? 0)"] = cell["lessons"] as? [[String:Any]] ?? []
    }
    let all = stack()
    let badges = stack(axis: .horizontal)
    let spacer = UIView(); spacer.widthAnchor.constraint(equalToConstant: 34).isActive = true
    badges.addArrangedSubview(spacer)
    var firstBadge: UIView?
    for column in columns {
      let badge = UIView()
      if let text = column["badge"] as? String, !text.isEmpty {
        let pill = UIView(); pill.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 10
        let textView = label(text, size: 11, weight: .bold, color: .systemIndigo, centered: true)
        pin(textView, to: pill, inset: 3)
        badge.addSubview(pill); pill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([pill.centerXAnchor.constraint(equalTo: badge.centerXAnchor), pill.centerYAnchor.constraint(equalTo: badge.centerYAnchor), pill.widthAnchor.constraint(lessThanOrEqualTo: badge.widthAnchor)])
      }
      badges.addArrangedSubview(badge)
      if let first = firstBadge { badge.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true } else { firstBadge = badge }
    }
    let badgeHeight = UIFontMetrics.default.scaledValue(for: 24)
    badges.heightAnchor.constraint(equalToConstant: badgeHeight).isActive = true
    all.addArrangedSubview(badges)
    let table = stack(); table.backgroundColor = .secondarySystemGroupedBackground
    table.layer.cornerRadius = 22; table.clipsToBounds = true
    all.addArrangedSubview(table)
    let headerHeight = UIFontMetrics.default.scaledValue(for: 52)
    var totalHeight = badgeHeight + headerHeight
    for period in 0...periods {
      let row = stack(axis: .horizontal)
      let count = period == 0 ? 1 : (0..<columns.count).map { cells["\($0):\(period)"]?.count ?? 0 }.max() ?? 1
      let height = period == 0 ? headerHeight : CGFloat(max(1,count)) * UIFontMetrics.default.scaledValue(for: 52)
      if period > 0 { totalHeight += height }
      row.heightAnchor.constraint(equalToConstant: height).isActive = true
      if period == 0 { row.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12) }
      let index = label(period == 0 ? "교시" : "\(period)", size: period == 0 ? 11 : 14, weight: .semibold, centered: true)
      index.widthAnchor.constraint(equalToConstant: 34).isActive = true
      row.addArrangedSubview(index)
      var firstCell: UIView?
      for (col, column) in columns.enumerated() {
        let box = UIView(); box.layer.borderColor = UIColor.separator.cgColor; box.layer.borderWidth = 0.25
        if period != 0 && column["highlighted"] as? Bool == true { box.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.09) }
        let values = stack(spacing: 2)
        if period == 0 {
          values.addArrangedSubview(label(column["label"] as? String ?? "", size: 17, weight: .bold, color: .systemIndigo, centered: true))
          values.addArrangedSubview(label(column["detail"] as? String ?? "", size: 11, centered: true))
        } else if let lessons = cells["\(col):\(period)"], !lessons.isEmpty {
          for lesson in lessons {
            let lines = stack(spacing: 1)
            lines.addArrangedSubview(label(lesson["subject"] as? String ?? "", size: 14, weight: .semibold, centered: true))
            if let secondary = lesson["secondary"] as? String, !secondary.isEmpty { lines.addArrangedSubview(label(secondary, size: 11, weight: .light, color: .secondaryLabel, centered: true)) }
            if lesson["changed"] as? Bool == true { lines.addArrangedSubview(label("대체", size: 11, weight: .bold, color: .systemIndigo, centered: true)) }
            let lessonBox = UIView()
            if lesson["changed"] as? Bool == true { lessonBox.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12) }
            pin(lines, to: lessonBox, inset: 3)
            lessonBox.accessibilityLabel = lesson["semantics"] as? String
            if let action = lesson["action"] as? String {
              let tap = UIButton(type: .custom)
              tap.accessibilityLabel = lesson["semantics"] as? String
              tap.addAction(UIAction { [weak self] _ in self?.emit(action) }, for: .touchUpInside)
              pin(tap, to: lessonBox)
            }
            values.addArrangedSubview(lessonBox)
          }
        } else { values.addArrangedSubview(label("—", size: 14, weight: .semibold, color: .tertiaryLabel, centered: true)) }
        box.addSubview(values); values.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([values.leadingAnchor.constraint(equalTo: box.leadingAnchor), values.trailingAnchor.constraint(equalTo: box.trailingAnchor), values.centerYAnchor.constraint(equalTo: box.centerYAnchor)])
        row.addArrangedSubview(box)
        if let first = firstCell { box.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true } else { firstCell = box }
      }
      table.addArrangedSubview(row)
    }
    // Weekly grids have no nested scroll view; the table owns every vertical drag.
    guard model["horizontal"] as? Bool == true else { return all }
    let horizontal = HorizontalTimetableScroll()
    horizontal.alwaysBounceHorizontal = false
    horizontal.showsVerticalScrollIndicator = false
    horizontal.contentInsetAdjustmentBehavior = .never
    horizontal.addSubview(all); all.translatesAutoresizingMaskIntoConstraints = false
    let wide = model["horizontal"] as? Bool == true
    NSLayoutConstraint.activate([all.topAnchor.constraint(equalTo: horizontal.contentLayoutGuide.topAnchor), all.leadingAnchor.constraint(equalTo: horizontal.contentLayoutGuide.leadingAnchor), all.trailingAnchor.constraint(equalTo: horizontal.contentLayoutGuide.trailingAnchor), all.bottomAnchor.constraint(equalTo: horizontal.contentLayoutGuide.bottomAnchor), all.heightAnchor.constraint(equalToConstant: totalHeight), all.widthAnchor.constraint(greaterThanOrEqualTo: horizontal.frameLayoutGuide.widthAnchor)])
    if wide { all.widthAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(34 + columns.count * 64)).isActive = true }
    let fit = all.widthAnchor.constraint(equalTo: horizontal.frameLayoutGuide.widthAnchor); fit.priority = .defaultHigh; fit.isActive = true
    horizontal.heightAnchor.constraint(equalToConstant: totalHeight + (wide ? 16 : 0)).isActive = true
    gridScroll = horizontal
    DispatchQueue.main.async { [weak horizontal, weak self] in
      guard let horizontal = horizontal else { return }
      horizontal.layoutIfNeeded()
      horizontal.contentOffset.x = min(self?.horizontalOffset ?? 0, max(0,horizontal.contentSize.width - horizontal.bounds.width))
    }
    return horizontal
  }
  private func addMeals(to content: UIStackView) {
    let dateRow = stack(axis: .horizontal)
    dateRow.backgroundColor = .tertiarySystemFill
    dateRow.layer.cornerRadius = 16
    func dateButton(_ title: String, action: String, arrow: Bool = false) -> UIButton {
      let button = UIButton(type: .system)
      if arrow {
        button.setImage(UIImage(systemName: title, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)), for: .normal)
        button.tintColor = .secondaryLabel
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
      } else {
        button.setTitle(title, for: .normal); button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .semibold))
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        button.accessibilityIdentifier = "meal-date"
      }
      button.addAction(UIAction { [weak self] _ in self?.emit(action) }, for: .touchUpInside)
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
      return button
    }
    let previous = dateButton("chevron.left", action: "previous", arrow: true); previous.accessibilityLabel = "이전 날짜"
    let next = dateButton("chevron.right", action: "next", arrow: true); next.accessibilityLabel = "다음 날짜"
    dateRow.addArrangedSubview(previous)
    dateRow.addArrangedSubview(dateButton(model["date"] as? String ?? "날짜 선택", action: "date"))
    dateRow.addArrangedSubview(next)
    let dateContainer = UIView(); dateContainer.addSubview(dateRow); dateRow.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([dateRow.centerXAnchor.constraint(equalTo: dateContainer.centerXAnchor), dateRow.topAnchor.constraint(equalTo: dateContainer.topAnchor), dateRow.bottomAnchor.constraint(equalTo: dateContainer.bottomAnchor), dateRow.widthAnchor.constraint(lessThanOrEqualTo: dateContainer.widthAnchor)])
    content.addArrangedSubview(dateContainer)
    switch model["status"] as? String {
    case "ready":
      for meal in model["meals"] as? [[String:Any]] ?? [] {
        let body = stack(spacing: 8)
        let header = stack(axis: .horizontal, spacing: 8)
        header.addArrangedSubview(label(meal["type"] as? String ?? "", size: 20, weight: .bold))
        header.addArrangedSubview(label(meal["calories"] as? String ?? "", size: 14, color: .secondaryLabel))
        body.addArrangedSubview(header)
        for dish in meal["dishes"] as? [[String:String]] ?? [] {
          let text = stack(spacing: 3)
          text.addArrangedSubview(label(dish["name"] ?? "", size: 16, weight: .semibold))
          let warning = dish["warning"] ?? ""
          if !warning.isEmpty { text.addArrangedSubview(label(warning, size: 14, weight: .semibold, color: .systemRed)) }
          if let allergens = dish["allergens"], !allergens.isEmpty { text.addArrangedSubview(label(allergens, size: 13, color: .secondaryLabel)) }
          let dishBox = UIView(); dishBox.layer.cornerRadius = 12
          if !warning.isEmpty { dishBox.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1) }
          pin(text, to: dishBox, inset: 6); body.addArrangedSubview(dishBox)
        }
        let card = UIView(); card.backgroundColor = .secondarySystemGroupedBackground; card.layer.cornerRadius = 18
        pin(body, to: card, inset: 14); content.addArrangedSubview(card)
      }
    case "empty":
      let body = stack(spacing: 16)
      if let encoded = model["emptyIllustration"] as? String, let data = Data(base64Encoded: encoded), let image = UIImage(data: data) {
        let artwork = UIImageView(image: image); artwork.contentMode = .scaleAspectFit
        artwork.accessibilityIdentifier = "empty-meal-illustration"; artwork.isAccessibilityElement = true; artwork.accessibilityLabel = "빈 식판 일러스트"
        artwork.heightAnchor.constraint(equalToConstant: 128).isActive = true
        body.addArrangedSubview(artwork)
      }
      body.addArrangedSubview(label("등록된 급식이 없습니다", size: 21, weight: .bold, centered: true))
      body.addArrangedSubview(label("다른 날짜의 식단을 확인해 주세요.", size: 17, color: .secondaryLabel, centered: true))
      let box = UIView(); box.addSubview(body); body.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([body.topAnchor.constraint(equalTo: box.topAnchor, constant: 44), body.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -44), body.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16), body.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)])
      content.addArrangedSubview(box)
    case "error": content.addArrangedSubview(result("급식을 불러오지 못했어요", detail: "잠시 후 다시 시도해 주세요.", symbol: "exclamationmark.circle")); content.addArrangedSubview(button("다시 시도", action: "retry"))
    default: content.addArrangedSubview(loading())
    }
    if model["showToday"] as? Bool == true { content.addArrangedSubview(button("오늘로 돌아가기", action: "today")) }
  }
}

// Reject vertical pans before recognition so the enclosing table receives them.
private final class HorizontalTimetableScroll: UIScrollView {
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer === panGestureRecognizer {
      let velocity = panGestureRecognizer.velocity(in: self)
      if abs(velocity.y) >= abs(velocity.x) { return false }
    }
    return super.gestureRecognizerShouldBegin(gestureRecognizer)
  }
}

private final class NativeStartupTimetable: UITableViewController, UISearchBarDelegate {
  let finish: FlutterResult
  let teachers: [[String: String]]
  let modes = ["mine", "classes", "teachers"]
  let labels = ["요일별 보기", "학급별 보기", "선생님별 보기"]
  var mode: String
  var teacher: String?
  var teacherLabel: String?
  var visible: [[String: String]] = []
  let search = UISearchBar()
  init(args: [String: Any], finish: @escaping FlutterResult) {
    self.finish = finish; teachers = args["teachers"] as? [[String: String]] ?? []
    mode = args["mode"] as? String ?? "mine"; teacher = args["teacher"] as? String; teacherLabel = args["label"] as? String
    super.init(style: .insetGrouped); title = "앱 시작 시 시간표"; visible = teachers
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    let saveSymbol: String
    if #available(iOS 26.0, *) { saveSymbol = "checkmark" } else { saveSymbol = "checkmark.circle" }
    navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: saveSymbol), style: .done, target: self, action: #selector(save))
    navigationItem.rightBarButtonItem?.accessibilityLabel = "저장"
    search.delegate = self; search.placeholder = "선생님 이름 검색"; search.searchBarStyle = .minimal
    updateSaveButton()
  }
  func updateSaveButton() {
    navigationItem.rightBarButtonItem?.isEnabled = mode != "teachers" || teachers.contains { $0["id"] == teacher }
  }
  func searchBar(_ searchBar: UISearchBar, textDidChange query: String) {
    let filtered = teachers.filter { query.isEmpty || (($0["label"] ?? "") + ($0["subjects"] ?? "")).localizedCaseInsensitiveContains(query) }
    let previousIDs = Set(visible.compactMap { $0["id"] })
    let nextIDs = Set(filtered.compactMap { $0["id"] })
    let removed = visible.indices.filter { !nextIDs.contains(visible[$0]["id"] ?? "") }.map { IndexPath(row: $0, section: 1) }
    let added = filtered.indices.filter { !previousIDs.contains(filtered[$0]["id"] ?? "") }.map { IndexPath(row: $0, section: 1) }
    visible = filtered
    guard mode == "teachers" else { return }
    // Keep the search field and keyboard alive while filtering only the rows.
    tableView.performBatchUpdates {
      tableView.deleteRows(at: removed, with: .automatic)
      tableView.insertRows(at: added, with: .automatic)
    }
  }
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    section == 1 ? search : nil
  }
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    section == 1 ? 56 : UITableView.automaticDimension
  }
  @objc func cancel() { dismiss(animated: true) { self.finish(nil) } }
  @objc func save() {
    let result: [String: Any] = ["mode": mode, "teacher": teacher as Any? ?? NSNull(), "label": teacherLabel as Any? ?? NSNull()]
    dismiss(animated: true) { self.finish(result) }
  }
  override func numberOfSections(in tableView: UITableView) -> Int { mode == "teachers" ? 2 : 1 }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 3 : visible.count }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? "시작할 보기 모드" : "시작할 선생님" }
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    if section == 1 && teachers.isEmpty { return "선생님 명단을 불러오지 못했어요. 시간표를 새로고침한 뒤 다시 열어 주세요." }
    return section == 0 ? "다음 앱 실행부터 적용돼요. 사용 중 보기 모드를 바꿔도 이 설정은 유지돼요." : nil
  }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    if indexPath.section == 0 {
      cell.textLabel?.text = labels[indexPath.row]; cell.accessoryType = mode == modes[indexPath.row] ? .checkmark : .none
    } else {
      let item = visible[indexPath.row]; cell.textLabel?.text = (item["label"] ?? "") + " 선생님"; cell.detailTextLabel?.text = item["subjects"]; cell.accessoryType = item["id"] == teacher ? .checkmark : .none
    }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let hadTeachers = mode == "teachers"
    if indexPath.section == 0 { mode = modes[indexPath.row] }
    else { teacher = visible[indexPath.row]["id"]; teacherLabel = visible[indexPath.row]["label"] }
    // Preserve the tapped cell so UIKit can finish its selection animation.
    for path in tableView.indexPathsForVisibleRows ?? [] {
      guard let cell = tableView.cellForRow(at: path) else { continue }
      let checked = path.section == 0 ? mode == modes[path.row] : visible[path.row]["id"] == teacher
      cell.accessoryType = checked ? .checkmark : .none
    }
    updateSaveButton()
    let hasTeachers = mode == "teachers"
    if hadTeachers != hasTeachers {
      if !hasTeachers { search.resignFirstResponder() }
      tableView.performBatchUpdates {
        if hasTeachers { tableView.insertSections(IndexSet(integer: 1), with: .automatic) }
        else { tableView.deleteSections(IndexSet(integer: 1), with: .automatic) }
      }
    }
  }
}
