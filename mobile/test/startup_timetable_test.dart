import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:schoolzip/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:schoolzip/startup_timetable.dart';
import 'package:schoolzip/timetable_views.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  testWidgets('재실행하면 지정한 선생님으로 열고 일시적 모드 변경은 저장하지 않는다', (tester) async {
    await const StartupTimetable(
      mode: TimetableMode.teachers,
      teacher: 'B',
      label: '이가람',
    ).save('1');
    final app = CupertinoApp(
      home: SchoolHome(
        saved: const {'code': 1, 'name': '검증학교', 'grade': '1', 'room': '1'},
        fetch: (_, _) async => {
          'start': '2026-11-16',
          'updated': 'test',
          'grades': {
            '1': {
              '1': [
                [
                  {
                    'period': 1,
                    'subject': '국어',
                    'teacher': '김가람',
                    'teacherId': 'A',
                  },
                  {
                    'period': 2,
                    'subject': '수학',
                    'teacher': '이가람',
                    'teacherId': 'B',
                  },
                ],
                [],
                [],
                [],
                [],
              ],
            },
          },
        },
      ),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('선생님별 보기'), findsOneWidget);
    expect(find.text('이가람 선생님'), findsOneWidget);
    await tester.tap(find.text('선생님별 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('요일별 보기'));
    await tester.pumpAndSettle();
    expect((await StartupTimetable.read('1')).teacher, 'B');
    expect((await StartupTimetable.read('1')).mode, TimetableMode.teachers);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('선생님별 보기'), findsOneWidget);
    expect(find.text('이가람 선생님'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('학교별 시작 모드와 선생님을 저장하고 복원한다', () async {
    await const StartupTimetable(
      mode: TimetableMode.teachers,
      teacher: 'teacher:123',
      label: '김가람',
    ).save('A');
    await const StartupTimetable(mode: TimetableMode.classes).save('B');
    final restored = await StartupTimetable.read('A');
    expect(restored.mode, TimetableMode.teachers);
    expect(restored.teacher, 'teacher:123');
    expect(restored.label, '김가람');
    expect((await StartupTimetable.read('B')).mode, TimetableMode.classes);
    expect((await StartupTimetable.read('C')).mode, TimetableMode.mine);
    await const StartupTimetable().save('A');
    expect((await StartupTimetable.read('A')).mode, TimetableMode.mine);
  });
  test('잘못된 저장값과 선생님 없는 설정은 기본 보기로 복구한다', () async {
    await SharedPreferencesAsync().setString('startupTimetable:A', 'broken');
    expect((await StartupTimetable.read('A')).mode, TimetableMode.mine);
    expect(
      StartupTimetable.fromJson({'mode': 'teachers'}).mode,
      TimetableMode.mine,
    );
    expect(
      StartupTimetable.fromJson({'mode': 'unknown'}).mode,
      TimetableMode.mine,
    );
  });
}
