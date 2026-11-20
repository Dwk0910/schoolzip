import XCTest
final class ScrollTests: XCTestCase {
  func testNativeScrollAndTabs() throws {
    let app = XCUIApplication(bundleIdentifier: "app.schoolzip.schoolzip")
    app.launch()
    let title = app.staticTexts["주간 시간표"].firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 15))
    let expanded = title.frame
    XCTAssertGreaterThan(expanded.height, 30)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
    sleep(1)
    XCTAssertLessThan(title.frame.height, expanded.height)
    let collapsed = XCTAttachment(screenshot: app.screenshot()); collapsed.name = "collapsed"; collapsed.lifetime = .keepAlways; add(collapsed)
    for _ in 0..<3 { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))) }
    sleep(1)
    XCTAssertGreaterThan(title.frame.height, 30)
    XCTAssertTrue(title.isHittable)
    let restored = XCTAttachment(screenshot: app.screenshot()); restored.name = "restored"; restored.lifetime = .keepAlways; add(restored)
    app.buttons["학교 바꾸기"].firstMatch.tap()
    XCTAssertTrue(app.staticTexts["학교 선택 완료"].waitForExistence(timeout: 5))
    app.buttons["본문 버튼"].firstMatch.tap()
    XCTAssertTrue(app.staticTexts["본문 터치 완료"].waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94)).tap()
    XCTAssertTrue(app.staticTexts["급식 식단표"].firstMatch.waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.71, dy: 0.94)).tap()
    XCTAssertTrue(app.staticTexts["설정"].firstMatch.waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.29, dy: 0.94)).tap()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
  }
}
