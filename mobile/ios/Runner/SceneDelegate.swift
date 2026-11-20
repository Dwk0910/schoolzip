import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let window = window, let flutter = window.rootViewController as? FlutterViewController else { return }
    let page = NativePageScrollController(flutter: flutter)
    let navigation = UINavigationController(rootViewController: page)
    navigation.navigationBar.prefersLargeTitles = true
    navigation.setNavigationBarHidden(true, animated: false)
    window.rootViewController = navigation
  }
}

// The real content surface is a child of this UIScrollView. UIKit owns the pan,
// deceleration, large-title transition, and scroll-edge effect in one hierarchy.
private final class NativePageScrollController: UIViewController, UIScrollViewDelegate {
  private let flutter: FlutterViewController
  private let scrollView = PageScrollView()
  private let channel: FlutterMethodChannel
  private var enabled = false
  private var maximum: CGFloat = 0
  private var expandedInset: CGFloat = 0
  private var initialOffset: CGFloat = 0
  private var configuring = false
  private var pageID = ""
  private var configurationVersion = 0

  init(flutter: FlutterViewController) {
    self.flutter = flutter
    channel = FlutterMethodChannel(name: "schoolzip/page-scroll", binaryMessenger: flutter.binaryMessenger)
    super.init(nibName: nil, bundle: nil)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else { reply(nil); return }
      switch call.method {
      case "configure":
        self.configure(call.arguments as? [String:Any] ?? [:])
      case "extent":
        self.maximum = CGFloat(truncating: call.arguments as? NSNumber ?? 0)
        self.updateContentSize()
      default: reply(FlutterMethodNotImplemented); return
      }
      reply(nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  override var childForStatusBarStyle: UIViewController? { flutter }
  override var childForStatusBarHidden: UIViewController? { flutter }
  override func loadView() {
    view = scrollView
    scrollView.delegate = self
    scrollView.backgroundColor = .systemGroupedBackground
    scrollView.isScrollEnabled = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.alwaysBounceVertical = true
    scrollView.isDirectionalLockEnabled = true
    scrollView.contentInsetAdjustmentBehavior = .always
    addChild(flutter)
    scrollView.addSubview(flutter.view)
    flutter.didMove(toParent: self)
    if #available(iOS 15.0, *) { setContentScrollView(scrollView, for: .top) }
  }
  private func configure(_ config: [String:Any]) {
    loadViewIfNeeded()
    configurationVersion += 1
    let version = configurationVersion
    configuring = true
    defer { configuring = false }
    enabled = config["enabled"] as? Bool ?? false
    scrollView.isScrollEnabled = enabled
    navigationController?.setNavigationBarHidden(!enabled, animated: false)
    if !enabled {
      maximum = 0
      expandedInset = 0
      scrollView.contentInsetAdjustmentBehavior = .never
      scrollView.setContentOffset(.zero, animated: false)
      updateContentSize()
      placeFlutterSurface()
      return
    }
    pageID = config["id"] as? String ?? ""
    title = config["title"] as? String
    navigationItem.largeTitleDisplayMode = .always
    navigationItem.rightBarButtonItem = (config["action"] as? String).map {
      UIBarButtonItem(title: $0, style: .plain, target: self, action: #selector(action))
    }
    maximum = CGFloat(truncating: config["maximum"] as? NSNumber ?? 0)
    initialOffset = CGFloat(truncating: config["offset"] as? NSNumber ?? 0)
    scrollView.contentInsetAdjustmentBehavior = .always
    scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
    navigationController?.view.layoutIfNeeded()
    expandedInset = scrollView.adjustedContentInset.top
    updateContentSize()
    scrollView.setContentOffset(CGPoint(x: 0, y: initialOffset - expandedInset), animated: false)
    placeFlutterSurface()
    channel.invokeMethod("metrics", arguments: ["id": pageID, "header": expandedInset])
    // UIKit settles the large-title inset after the first navigation layout.
    // Capture that expanded baseline before restoring this tab's scroll position.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.enabled, self.configurationVersion == version else { return }
      self.configuring = true
      self.scrollView.setContentOffset(CGPoint(x: 0, y: -self.scrollView.adjustedContentInset.top - UIFont.preferredFont(forTextStyle: .largeTitle).lineHeight * 2), animated: false)
      self.navigationController?.view.layoutIfNeeded()
      self.expandedInset = self.navigationController?.navigationBar.frame.maxY ?? self.scrollView.adjustedContentInset.top
      self.updateContentSize()
      self.scrollView.setContentOffset(CGPoint(x: 0, y: self.initialOffset - self.expandedInset), animated: false)
      self.placeFlutterSurface()
      self.channel.invokeMethod("metrics", arguments: ["id": self.pageID, "header": self.expandedInset])
      self.configuring = false
    }
  }
  @objc private func action() { channel.invokeMethod("action", arguments: pageID) }
  private func updateContentSize() {
    // Flutter renders the full viewport; its logical extent supplies the native range.
    scrollView.contentSize = CGSize(width: view.bounds.width, height: max(1, view.bounds.height + maximum - expandedInset - scrollView.adjustedContentInset.bottom))
  }
  private func placeFlutterSurface() {
    // Keep overlays/tab bar anchored while the page's content follows the native offset.
    flutter.view.frame = CGRect(origin: scrollView.contentOffset, size: view.bounds.size)
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateContentSize()
    placeFlutterSurface()
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    placeFlutterSurface()
    guard enabled, !configuring else { return }
    channel.invokeMethod("scroll", arguments: ["id": pageID, "offset": max(0, scrollView.contentOffset.y + expandedInset)])
  }
}

// Horizontal timetable gestures remain with the Flutter content.
private final class PageScrollView: UIScrollView {
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer === panGestureRecognizer {
      let velocity = panGestureRecognizer.velocity(in: self)
      if abs(velocity.x) > abs(velocity.y) { return false }
    }
    return super.gestureRecognizerShouldBegin(gestureRecognizer)
  }
}
