import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolzip/main.dart';
import 'package:schoolzip/intro_guide.dart';

void main() {
  testWidgets('새로 설치하면 도움말보다 먼저 학교 설정이 열린다', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const Schoolzip());
    await tester.pumpAndSettle();
    expect(find.text('스쿨집 시작하기'), findsOneWidget);
    expect(find.text('스쿨집 사용 안내'), findsNothing);
    expect((await readLaunchState()).showGuide, isTrue);
  });

  testWidgets('검색 결과와 학급 목록을 기다릴 때 같은 높이에 로더가 뜬다', (tester) async {
    final search = Completer<dynamic>(), timetable = Completer<dynamic>();
    await tester.pumpWidget(
      CupertinoApp(
        home: SchoolHome(
          fetch: (path, _) =>
              path == 'schools' ? search.future : timetable.future,
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '오남');
    await tester.tap(find.text('검색'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final indicator = find.byType(CupertinoActivityIndicator);
    final searchY = tester.getCenter(indicator).dy;
    search.complete([
      {'name': '오남고등학교', 'region': '경기', 'code': 43373},
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('오남고등학교'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.getCenter(indicator).dy, closeTo(searchY, 1));
    timetable.complete({'grades': <String, dynamic>{}});
    await tester.pumpAndSettle();
  });
  testWidgets('저장한 이번 주 시간표를 먼저 보여주고 새 응답으로 교체한다', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final start = now
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .substring(0, 10);
    Map<String, dynamic> schedule(String subject) => {
      'start': start,
      'updated': start,
      'grades': {
        '1': {
          '7': [
            [
              {'period': 1, 'subject': subject},
            ],
          ],
        },
      },
    };
    final response = Completer<dynamic>();
    await tester.runAsync(() async {
      await SharedPreferencesAsync().setString(
        'lastWeek',
        jsonEncode({'code': 43373, 'table': schedule('기존 수업')}),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: SchoolHome(
            saved: const {
              'name': '오남고등학교',
              'grade': '1',
              'room': '7',
              'code': 43373,
            },
            fetch: (_, _) => response.future,
          ),
        ),
      );
      for (var i = 0; i < 50 && find.text('기존 수업').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    expect(find.text('기존 수업'), findsOneWidget);
    response.complete(schedule('변경 수업'));
    await tester.pumpAndSettle();
    expect(find.text('변경 수업'), findsOneWidget);
    expect(find.text('기존 수업'), findsNothing);
  });

  testWidgets('검색 실패 후 같은 학교명으로 다시 시도해 결과를 연다', (tester) async {
    int attempts = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: SchoolHome(
          fetch: (path, query) async {
            if (path == 'schools') {
              expect(query['q'], '스쿨집');
              if (++attempts == 1) throw StateError('offline');
              return [
                {'code': 1, 'name': '스쿨집고등학교', 'region': '경기'},
              ];
            }
            return {'grades': <String, dynamic>{}};
          },
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '스쿨집');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('학교를 검색하지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('스쿨집고등학교'), findsOneWidget);
    expect(find.byType(ErrorResult), findsNothing);
  });

  testWidgets('주차 전환 양방향에서 헤더 아래 로더와 선택한 반만 유지한다', (tester) async {
    final next = Completer<dynamic>(), current = Completer<dynamic>();
    Map<String, dynamic> table(String date, String subject) => {
      'start': date,
      'updated': date,
      'grades': {
        '2': {
          '3': [
            [
              {'period': 1, 'subject': subject, 'teacher': '이혜'},
            ],
          ],
        },
      },
    };
    await tester.pumpWidget(
      CupertinoApp(
        home: WeeklyPage(
          school: const {'name': '검증학교', 'code': 12},
          preferred: null,
          changeSchool: () {},
          remember: (_, _, _) async {},
          initialWeek: Future.value(table('2026-03-09', '국어')),
          fetch: (_, args) =>
              args['week'] == '1' ? next.future : current.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> check(String button, String date, String old) async {
      await tester.tap(find.text(button));
      await tester.pump();
      expect(find.text('2학년 3반'), findsOneWidget);
      expect(find.text(old), findsNothing);
      expect(find.text('등록된 수업 없음'), findsNothing);
      final loader = find.byType(CupertinoActivityIndicator);
      expect(
        tester.getCenter(loader).dy,
        greaterThan(tester.getBottomLeft(find.text(date)).dy),
      );
      expect(
        (tester.getCenter(loader).dx - tester.getCenter(find.byType(Table)).dx)
            .abs(),
        lessThan(1),
      );
    }

    await check('다음 주', '3/16', '국어');
    next.complete(table('2026-03-16', '미술'));
    await tester.pumpAndSettle();
    await check('이번 주', '3/9', '미술');
    current.complete(table('2026-03-09', '국어'));
    await tester.pumpAndSettle();
    expect(find.text('이혜'), findsOneWidget);
  });
  testWidgets('과목과 학교별 교사 이름을 저장하고 다시 열어 복원한다', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final published = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('schoolzip/today'),
      (call) async {
        published.add(call);
        return null;
      },
    );
    Future<void> openSchool(int code) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: SchoolHome(
            key: ValueKey(code),
            saved: {'name': '테스트학교', 'code': code, 'grade': '1', 'room': '1'},
            fetch: (_, _) async => {
              'start': '2026-03-09',
              'updated': '2026-03-09',
              'grades': {
                '1': {
                  '1': [
                    [
                      {'period': 1, 'subject': '수학', 'teacher': '이혜'},
                      {'period': 2, 'subject': '음악', 'teacher': '이혜'},
                      {'period': 3, 'subject': '수학', 'teacher': '이혜'},
                    ],
                  ],
                },
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openSchool(1);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선생님 이름 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수학'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '이혜진');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('시간표').last);
    await tester.pumpAndSettle();
    expect(find.text('이혜진'), findsNWidgets(2));
    expect(find.text('이혜'), findsOneWidget);
    expect(jsonDecode(published.last.arguments['names']), {
      '수학': {'이혜': '이혜진'},
    });
    await openSchool(2);
    expect(find.text('이혜'), findsNWidgets(3));
    await openSchool(1);
    expect(find.text('이혜진'), findsNWidgets(2));
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선생님 이름 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수학'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('컴시간 이름으로 복원'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('시간표').last);
    await tester.pumpAndSettle();
    expect(find.text('이혜'), findsNWidgets(3));
  });
  testWidgets('학교와 반을 선택하고 다음 주 시간표로 전환한다', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    MethodCall? widgetConfig;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('schoolzip/today'),
      (call) async {
        if (call.method == 'configure') widgetConfig = call;
        return null;
      },
    );
    int timetableRequests = 0;
    Future<dynamic> fetch(String path, Map<String, String> query) async {
      if (path == 'schools') {
        expect(query['q'], '오남');
        return [
          {'name': '오남고등학교', 'region': '경기', 'code': 43373},
        ];
      }
      timetableRequests++;
      expect(query['code'], '43373');
      final next = query['week'] == '1';
      return {
        'start': next ? '2026-11-23' : '2026-11-16',
        'updated': '2026-11-16',
        'grades': {
          '1': {
            '1': [[]],
            '7': [
              [
                {
                  'period': 4,
                  'subject': next ? '공수2' : '음악',
                  'teacher': '테스트',
                  'changed': !next,
                  if (!next) 'original': {'subject': '공수2', 'teacher': '김가'},
                },
              ],
            ],
          },
        },
      };
    }

    await tester.pumpWidget(
      CupertinoApp(home: SchoolHome(fetch: fetch, showGuide: true)),
    );
    expect(find.text('스쿨집 시작하기'), findsOneWidget);
    expect(find.bySemanticsLabel('2단계 중 1단계, 학교 선택'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '오남');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오남고등학교'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('2단계 중 2단계, 학교 선택 완료, 학급 선택'), findsOneWidget);
    await tester.tap(find.text('7반'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(widgetConfig, isNull);
    await tester.tap(find.text('오남고등학교'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7반'));
    await tester.pumpAndSettle();
    expect(
      timetableRequests,
      1,
    ); // The single result and both selections share a fetch.
    final requestsBeforeSave = timetableRequests;
    await tester.tap(find.text('1학년 7반으로 시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.bySemanticsLabel('학교·학급 설정 완료'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.getTopLeft(find.byType(WeeklyPage)).dx, greaterThan(0));
    expect(find.text('음악'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('스쿨집 사용 안내'), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.text('$i / 5'), findsOneWidget);
      final preview = find.byType(IntroGuide);
      for (final real in ['오남고등학교', '1학년 7반', '테스트', '테스트 선생님', '김가 선생님']) {
        expect(
          find.descendant(of: preview, matching: find.text(real)),
          findsNothing,
        );
      }
      expect(find.text('가상 시간표 예시'), findsNothing);
      expect(
        find.text('안내 속 학교와 수업은 모두 가상이에요.'),
        i == 1 ? findsOneWidget : findsNothing,
      );
      if (i == 1) {
        expect(
          find.descendant(of: preview, matching: find.text('다솜')),
          findsWidgets,
        );
      }
      if (i == 4) expect(find.text('누리 선생님'), findsOneWidget);
      if (i == 3) expect(find.text('등록된 수업 없음'), findsNothing);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    expect(find.text('5 / 5'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(IntroGuide),
        matching: find.text('스쿨집고등학교'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('시작하기!'));
    await tester.pumpAndSettle();
    expect(find.text('스쿨집 사용 안내'), findsNothing);
    expect(await SharedPreferencesAsync().getBool('guideSeen'), isTrue);
    expect(tester.getTopLeft(find.byType(WeeklyPage)).dx, 0);
    expect(timetableRequests, requestsBeforeSave);
    expect(widgetConfig?.arguments['room'], '7');
    expect(find.text('음악'), findsOneWidget);
    expect(find.text('테스트'), findsOneWidget);
    expect(find.text('대체'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.bySemanticsLabel('월요일 4교시 음악 대체 테스트 선생님'), findsOneWidget);
    expect(find.bySemanticsLabel('금요일 4교시 빈 교시'), findsOneWidget);
    await tester.tap(find.text('1학년 7반').first);
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('draggable-sheet'));
    await tester.dragFrom(
      tester.getTopLeft(picker) + const Offset(80, 10),
      const Offset(0, 280),
    );
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    await tester.tap(find.text('대체'));
    await tester.pumpAndSettle();
    expect(find.text('변경 전'), findsOneWidget);
    expect(find.text('공수2'), findsOneWidget);
    expect(find.text('김가 선생님'), findsOneWidget);
    expect(find.text('변경 후'), findsOneWidget);
    expect(find.text('테스트 선생님'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대체'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('lesson-change-sheet'));
    await tester.dragFrom(
      tester.getTopLeft(sheet) + const Offset(100, 12),
      const Offset(0, 250),
    );
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);

    await tester.tap(find.text('다음 주'));
    await tester.pumpAndSettle();
    expect(find.textContaining('공수2'), findsOneWidget);
    expect(find.text('11/23'), findsOneWidget);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('학교 설정'), findsOneWidget);
    await tester.tap(find.text('선생님 이름 표시'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 열 강조'));
    await tester.pumpAndSettle();
    final display = await readLaunchState();
    expect(display.teachers, isFalse);
    expect(display.highlight, isFalse);

    await tester.tap(find.text('전체 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('시간표').last);
    await tester.pumpAndSettle();
    expect(find.text('11/23'), findsOneWidget);
    await tester.tap(find.text('학교 바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('우리 학교 시간표'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('1학년 7반'), findsOneWidget);
    expect(find.text('11/23'), findsOneWidget);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 초기화'));
    await tester.pumpAndSettle();
    final thumb = find.byKey(const ValueKey('delete-thumb'));
    await tester.tap(thumb);
    await tester.pumpAndSettle();
    expect(find.text('밀어서 삭제'), findsOneWidget);
    await tester.drag(thumb, const Offset(65, 0));
    await tester.pumpAndSettle();
    expect(find.text('밀어서 삭제'), findsOneWidget);
    await tester.drag(
      thumb,
      Offset(tester.getSize(find.byType(CupertinoApp)).width, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('스쿨집 시작하기'), findsOneWidget);
    expect((await readLaunchState()).saved, isNull);
  });
}
