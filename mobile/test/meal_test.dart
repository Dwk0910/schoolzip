import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolzip/meals.dart';
import 'package:schoolzip/sheets.dart';

void main() {
  testWidgets('오늘 표시는 선택 날짜와 독립적이고 달을 왕복해도 유지된다', (tester) async {
    final korea = DateTime.now().toUtc().add(const Duration(hours: 9));
    final today = DateTime(korea.year, korea.month, korea.day);
    final other = DateTime(today.year, today.month, today.day == 1 ? 2 : 1);
    Future<void> show(DateTime initial) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: MealDateSheet(key: ValueKey(initial), initial: initial),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(other);
    expect(find.byKey(const ValueKey('meal-calendar-today')), findsOneWidget);
    final day = find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.label ?? '').endsWith(', 오늘'),
    );
    expect(day, findsOneWidget);
    expect(tester.widget<Semantics>(day).properties.selected, false);
    await tester.tap(find.bySemanticsLabel('다음 달'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meal-calendar-today')), findsNothing);
    await tester.tap(find.bySemanticsLabel('이전 달'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meal-calendar-today')), findsOneWidget);
    await show(today);
    expect(tester.widget<Semantics>(day).properties.selected, true);
    expect(find.byKey(const ValueKey('meal-calendar-today')), findsOneWidget);
  });
  testWidgets('4주부터 6주까지 달을 넘겨도 시트와 이동 버튼 위치가 유지된다', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (ctx) => CupertinoButton(
            child: const Text('열기'),
            onPressed: () => showSchoolSheet<DateTime>(
              context: ctx,
              builder: (_) => MealDateSheet(initial: DateTime(2026, 2, 1)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final next = find.bySemanticsLabel('다음 달');
    final button = tester.getCenter(next);
    final sheet = tester.getRect(find.byType(MealDateSheet));
    for (var month = 3; month <= 5; month++) {
      await tester.tapAt(button);
      await tester.pumpAndSettle();
      expect(find.text('2026년 $month월'), findsOneWidget);
      expect(tester.getCenter(next), button);
      expect(tester.getRect(find.byType(MealDateSheet)), sheet);
    }
  });
  testWidgets('달력에서 윤년 2월을 찾아 날짜를 바로 선택한다', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (ctx) => CupertinoButton(
            child: const Text('날짜 열기'),
            onPressed: () async {
              selected = await Navigator.push<DateTime>(
                ctx,
                CupertinoPageRoute(
                  builder: (_) => MealDateSheet(initial: DateTime(2024, 3, 1)),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('날짜 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2024년 2월'), findsOneWidget);
    await tester.tap(find.text('29'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2024, 2, 29));
  });
  testWidgets('급식 탭을 열 때 조회하고 날짜별 식단과 빈 날을 구분한다', (tester) async {
    final dates = <String>[];
    Widget app(bool active) => CupertinoApp(
      home: MealPage(
        school: const {'name': '오남고등학교', 'region': '경기'},
        active: active,
        allergies: const {2},
        fetch: (path, q) async {
          expect(path, 'meals');
          expect(q['region'], '경기');
          dates.add(q['date']!);
          return dates.length == 1 || dates.length == 4
              ? [
                  {
                    'type': '중식',
                    'calories': '818.2 Kcal',
                    'dishes': ['전복밥 (2.13.16.18)'],
                  },
                ]
              : [];
        },
      ),
    );
    await tester.pumpWidget(app(false));
    expect(dates, isEmpty);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('전복밥'), findsOneWidget);
    expect(find.text('내 알레르기 · 우유'), findsOneWidget);
    expect(find.text('오늘로 돌아가기'), findsNothing);
    await tester.tap(find.bySemanticsLabel('다음 날짜'));
    await tester.pumpAndSettle();
    expect(dates.length, 2);
    expect(dates.first, isNot(dates.last));
    expect(find.text('등록된 급식이 없습니다'), findsOneWidget);
    await tester.tap(find.text('오늘로 돌아가기'));
    await tester.pumpAndSettle();
    expect(dates.last, dates.first);
    expect(find.text('오늘로 돌아가기'), findsNothing);
    await tester.tap(find.bySemanticsLabel('이전 날짜'));
    await tester.pumpAndSettle();
    final button = find.text('오늘로 돌아가기');
    expect(button, findsOneWidget);
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getBottomLeft(find.text('전복밥')).dy),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(dates.last, dates.first);
    expect(button, findsNothing);
  });
}
