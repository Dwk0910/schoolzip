import XCTest
final class ScrollTests: XCTestCase {
  func testMealCardHierarchy() throws {
    let app = XCUIApplication(bundleIdentifier: "app.schoolzip.schoolzip"); app.launch()
    XCTAssertTrue(app.staticTexts["주간 시간표"].firstMatch.waitForExistence(timeout: 15))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94)).tap()
    XCTAssertTrue(app.staticTexts["중식"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["782.4 Kcal"].exists)
    XCTAssertTrue(app.staticTexts["현미밥"].exists)
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "meal-card-hierarchy"; shot.lifetime = .keepAlways; add(shot)
  }
  func testStartupModeSelection() throws {
    let app = XCUIApplication(bundleIdentifier: "app.schoolzip.schoolzip")
    app.launch()
    XCTAssertTrue(app.staticTexts["주간 시간표"].firstMatch.waitForExistence(timeout: 15))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.71, dy: 0.94)).tap()
    let row = app.cells.containing(.staticText, identifier: "앱 시작 시 시간표").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
    XCTAssertTrue(app.staticTexts["시간표 설정을 불러오는 중이에요."].waitForExistence(timeout: 2))
    XCTAssertFalse(app.buttons["저장"].firstMatch.isEnabled)
    XCTAssertTrue(app.staticTexts["시간표 설정을 불러오지 못했어요."].waitForExistence(timeout: 5))
    app.buttons["다시 시도"].tap()
    let teacherMode = app.staticTexts["선생님별 보기"].firstMatch
    XCTAssertTrue(teacherMode.waitForExistence(timeout: 5))
    app.staticTexts["요일별 보기"].firstMatch.tap()
    teacherMode.tap()
    let teacher = app.staticTexts["이가람 선생님"].firstMatch
    XCTAssertTrue(teacher.waitForExistence(timeout: 5))
    let search = app.textFields["선생님 이름 검색"].firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    let teacherCell = app.cells.containing(.staticText, identifier: "김가람 선생님").firstMatch
    XCTAssertEqual(search.frame.minX, teacherCell.frame.minX, accuracy: 1)
    XCTAssertEqual(search.frame.maxX, teacherCell.frame.maxX, accuracy: 1)
    XCTAssertGreaterThanOrEqual(teacherCell.frame.minY - search.frame.maxY, 12)
    let layout = XCTAttachment(screenshot: app.screenshot()); layout.name = "startup-search-aligned"; layout.lifetime = .keepAlways; add(layout)
    search.tap(); search.typeText("이가")
    XCTAssertFalse(app.staticTexts["김가람 선생님"].exists)
    XCTAssertEqual(app.textFields.firstMatch.value as? String, "이가")
    teacher.tap()
    let selected = XCTAttachment(screenshot: app.screenshot()); selected.name = "startup-teacher-selected"; selected.lifetime = .keepAlways; add(selected)
    app.staticTexts["학급별 보기"].firstMatch.tap()
    XCTAssertFalse(teacher.exists)
    teacherMode.tap()
    XCTAssertTrue(teacher.waitForExistence(timeout: 5))
    let save = app.buttons["저장"].firstMatch
    XCTAssertTrue(save.isEnabled); save.tap()
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.staticTexts["선생님별 보기"].waitForExistence(timeout: 5))
    let summary = XCTAttachment(screenshot: app.screenshot()); summary.name = "startup-settings-summary"; summary.lifetime = .keepAlways; add(summary)
    row.tap()
    XCTAssertTrue(app.staticTexts["시간표 설정을 불러오는 중이에요."].waitForExistence(timeout: 2))
    app.navigationBars["앱 시작 시 시간표"].buttons.element(boundBy: 0).tap()
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.staticTexts["선생님별 보기"].exists)
  }
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
    app.buttons["1학년 7반"].firstMatch.tap()
    XCTAssertTrue(app.staticTexts["본문 터치 완료"].waitForExistence(timeout: 5))
    app.buttons["요일별 보기"].firstMatch.tap()
    let option = app.buttons["모드 선택 확인"].firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.tap()
    XCTAssertTrue(app.staticTexts["선택 완료"].waitForExistence(timeout: 5))
    // Start inside a horizontally scrollable grid, not in the page margin.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
    XCTAssertLessThan(title.frame.height, expanded.height)
    let wide = XCTAttachment(screenshot: app.screenshot()); wide.name = "wide-grid-vertical-scroll"; wide.lifetime = .keepAlways; add(wide)
    for _ in 0..<3 { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))) }
    XCTAssertGreaterThan(title.frame.height, 30)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94)).tap()
    XCTAssertTrue(app.staticTexts["급식 식단표"].firstMatch.waitForExistence(timeout: 5))
    let mealTitle = app.staticTexts["급식 식단표"].firstMatch
    let date = app.buttons["meal-date"].firstMatch
    XCTAssertTrue(date.waitForExistence(timeout: 5))
    XCTAssertTrue(app.images["empty-meal-illustration"].waitForExistence(timeout: 5))
    XCTAssertLessThan(app.buttons["이전 날짜"].frame.width, 50)
    date.tap()
    XCTAssertTrue(app.buttons["다음 달"].firstMatch.waitForExistence(timeout: 5))
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "오늘")).firstMatch.tap()
    let mealFrame = mealTitle.frame
    let dateFrame = date.frame
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
    sleep(1)
    XCTAssertEqual(mealTitle.frame.minY, mealFrame.minY, accuracy: 1)
    XCTAssertEqual(mealTitle.frame.height, mealFrame.height, accuracy: 1)
    XCTAssertEqual(date.frame.minY, dateFrame.minY, accuracy: 1)
    let shortPage = XCTAttachment(screenshot: app.screenshot()); shortPage.name = "short-content"; shortPage.lifetime = .keepAlways; add(shortPage)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.71, dy: 0.94)).tap()
    XCTAssertTrue(app.staticTexts["설정"].firstMatch.waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.29, dy: 0.94)).tap()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
  }
}
