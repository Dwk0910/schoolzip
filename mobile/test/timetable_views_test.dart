import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:schoolzip/main.dart';
import 'package:schoolzip/controls.dart';
import 'package:schoolzip/teacher_names.dart';
import 'package:schoolzip/timetable_grid.dart';
import 'package:schoolzip/timetable_views.dart';

Map<String, dynamic> fixture(int week) => {
  'start': week == 0 ? '2026-11-16' : '2026-11-23',
  'updated': '2026-11-20',
  'grades': {
    '1': {
      '1': [
        [
          {
            'period': 1,
            'subject': '국어',
            'teacher': '가교사',
            'teacherId': 'roster:1',
          },
        ],
        [],
      ],
      '2': [
        [
          {
            'period': 1,
            'subject': week == 0 ? '영어' : '다음영어',
            'teacher': '나교사',
            'teacherId': 'roster:2',
          },
        ],
        [],
      ],
      '10': [
        [
          {
            'period': 2,
            'subject': '수학',
            'teacher': '가교사',
            'teacherId': 'roster:1',
          },
        ],
        [],
      ],
    },
    '2': {
      '1': [
        [
          {
            'period': 1,
            'subject': '음악',
            'teacher': '나교사',
            'teacherId': 'roster:2',
          },
        ],
        [],
      ],
    },
  },
};

void main() {
  test('학교 전체 학급과 같은 교시의 복수 수업을 보존한다', () {
    final lessons = schoolLessons(fixture(0)['grades']);
    expect(lessons.length, 4);
    final teacher = lessons.where((e) => e.lesson['teacher'] == '나교사').toList();
    expect(teacher.length, 2);
    expect(teacher.map((e) => e.grade), ['1', '2']);
    expect(['10', '2', '1']..sort(naturalOrder), ['1', '2', '10']);
  });

  testWidgets('학급별 가로 스크롤바는 안전 영역에 밀리지 않고 표 아래에 놓인다', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 180,
              child: TimetableOverview(
                mode: TimetableMode.classes,
                grades: fixture(0)['grades'],
                grade: '1',
                room: '1',
                start: DateTime(2026, 11, 16),
                selectedDay: 0,
                teacherLabel: (e) => e['teacher'],
                showTeachers: true,
                onChange: (_, _, _) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollbar = find.byType(CupertinoScrollbar);
    expect(MediaQuery.paddingOf(tester.element(scrollbar)).bottom, 0);
    final grid = find.byType(TimetableGrid);
    expect(
      tester.getBottomLeft(scrollbar).dy - tester.getBottomLeft(grid).dy,
      16,
    );
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(scrollbar).dy - tester.getBottomLeft(grid).dy,
      16,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('선택한 선생님의 수업이 없는 주에도 다른 선생님으로 바뀌지 않는다', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: SingleChildScrollView(
          child: TimetableOverview(
            mode: TimetableMode.teachers,
            grades: fixture(0)['grades'],
            grade: '1',
            room: '1',
            start: DateTime(2026, 11, 16),
            selectedTeacher: '수업없는교사',
            teacherLabel: (lesson) => lesson['teacher'],
            showTeachers: true,
            onChange: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('국어'), findsNothing);
    expect(find.text('등록된 수업이 없어요'), findsOneWidget);
  });

  testWidgets('세 보기의 주 선택과 선생님·요일 선택을 유지하고 메뉴를 위에 배치한다', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final requests = <String>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: WeeklyPage(
          school: const {'name': '검증학교', 'code': 12},
          preferred: null,
          changeSchool: () {},
          remember: (_, _, _) async {},
          initialWeek: Future.value(fixture(0)),
          fetch: (_, args) async {
            requests.add(args['week']!);
            return fixture(int.parse(args['week']!));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mode = find.byKey(const ValueKey('timetable-view-mode'));
    expect(
      tester.getBottomLeft(mode).dy,
      lessThan(tester.getTopLeft(find.byType(WeekControl)).dy),
    );
    Future<void> choose(String label) async {
      await tester.tap(mode);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    final selector = find.byKey(const ValueKey('timetable-context-selector'));
    expect(
      tester.getTopLeft(mode).dx,
      lessThan(tester.getTopLeft(selector).dx),
    );
    expect(find.byType(ViewDropdown), findsNWidgets(2));
    await choose('선생님별 보기');
    expect(find.byType(ViewDropdown), findsNWidgets(2));
    expect(
      find.descendant(of: selector, matching: find.text('가교사 선생님')),
      findsOneWidget,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '나교사');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TeacherPickerSheet),
        matching: find.text('가교사 선생님'),
      ),
      findsNothing,
    );
    expect(find.text('적용'), findsNothing);
    expect(find.text('취소'), findsOneWidget);
    await tester.tap(find.text('나교사 선생님').last);
    await tester.pumpAndSettle();
    expect(find.text('1학년 2반'), findsOneWidget);
    expect(find.text('2학년 1반'), findsOneWidget);
    expect(find.byType(TimetableGrid), findsOneWidget);
    await tester.tap(find.text('다음 주'));
    await tester.pumpAndSettle();
    expect(requests.last, '1');
    expect(
      find.descendant(of: selector, matching: find.text('나교사 선생님')),
      findsOneWidget,
    );
    expect(find.text('다음영어'), findsOneWidget);
    await choose('학급별 보기');
    expect(find.byType(ViewDropdown), findsNWidgets(2));
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2학년'));
    await tester.scrollUntilVisible(
      find.text('11/24 (화)'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(GradeDatePickerSheet),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('11/24 (화)'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(find.text('2학년 · 11/24 (화)'), findsOneWidget);
    expect(find.text('등록된 수업이 없어요'), findsOneWidget);
    expect(find.byType(WeekControl), findsNothing);
    expect(find.byType(Table), findsNothing);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1학년'));
    await tester.tap(find.text('11/16 (월)'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(requests.last, '0');
    expect(find.text('우리 반'), findsOneWidget);
    expect(find.text('1반'), findsOneWidget);
    expect(find.text('2반'), findsOneWidget);
    expect(find.text('10반'), findsOneWidget);
    expect(find.byType(TimetableGrid), findsOneWidget);
    await choose('요일별 보기');
    expect(find.byType(TimetableOverview), findsNothing);
    expect(find.byType(TimetableGrid), findsOneWidget);
    expect(find.byType(WeekControl), findsOneWidget);
    expect(
      find.descendant(of: selector, matching: find.text('1학년 1반')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('여러 수업으로 높아진 행도 오늘 배경이 전체 높이를 채운다', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: TimetableGrid(
          columns: [
            GridColumn('월', '11/16'),
            GridColumn('금', '11/20', today: true, highlighted: true),
          ],
          periods: 1,
          cells: {
            (0, 1): [
              GridLesson(subject: '국어', secondary: '1학년 1반'),
              GridLesson(subject: '영어', secondary: '2학년 1반'),
            ],
          },
        ),
      ),
    );
    final table = find.byType(Table);
    final highlights = find.descendant(
      of: table,
      matching: find.byType(ColoredBox),
    );
    final sizes = tester.widgetList<ColoredBox>(highlights).toList();
    final highlighted = sizes.firstWhere(
      (box) => box.color.a > 0 && box.color.a < .1,
    );
    expect(
      tester.getSize(find.byWidget(highlighted)).height,
      greaterThanOrEqualTo(100),
    );
    expect(tester.takeException(), isNull);
  });

  test('마스킹된 이름 수정과 검색은 원래 키를 유지하고 과목별로 구분한다', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = SchoolTeacherNames('hanmin-test');
    await store.save('국어', '*', '김민');
    final names = await store.read();
    final grades = {
      '1': {
        '1': [
          [
            {'period': 1, 'subject': '국어', 'teacher': '*'},
            {'period': 2, 'subject': '영어', 'teacher': '*'},
          ],
        ],
      },
    };
    final choices = teacherChoices(
      grades,
      (lesson) =>
          names[lesson['subject']]?[lesson['teacher']] ?? lesson['teacher'],
    );
    expect(choices.length, 2);
    final renamed = choices.firstWhere((e) => e.label == '김민');
    expect(renamed.original, '*');
    expect(renamed.matches('김민'), isTrue);
    expect(renamed.matches('*'), isTrue);
    expect(renamed.id, isNot(choices.firstWhere((e) => e.label == '*').id));
    await store.save('국어', '*', '');
    expect((await store.read())['국어'], isNull);
  });
}
