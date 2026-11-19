import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:schoolzip/teacher_names.dart';
import 'package:schoolzip/timetable_views.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test('원본 마스킹을 보존하고 두 글자 원본에만 마스킹을 보충한다', () {
    for (final pair in [
      ('이혜', '이혜*'),
      ('김가*', '김가*'),
      ('김*가', '김*가'),
      ('*', '*'),
      ('김민수', '김민수'),
      ('민', '민'),
      ('', ''),
    ]) {
      expect(originalTeacherLabel(pair.$1), pair.$2);
    }
    expect(
      resolvedTeacherName(
        {
          '@id:a': {'이혜': '혜진'},
        },
        {'subject': '수학', 'teacher': '이혜', 'teacherId': 'a'},
      ),
      '혜진',
    );
  });
  test('과목 변경은 동일 교사로 묶고 동명이인과 마스킹 이름은 인덱스로 구분한다', () {
    final lessons = [
      {'period': 1, 'subject': '공수1', 'teacher': '김가*', 'teacherId': 'a'},
      {'period': 2, 'subject': '공수2', 'teacher': '김가*', 'teacherId': 'a'},
      {'period': 3, 'subject': '공수2', 'teacher': '김가*', 'teacherId': 'b'},
      {'period': 4, 'subject': '영어', 'teacher': '*', 'teacherId': 'c'},
      {'period': 5, 'subject': '영어', 'teacher': '*', 'teacherId': 'd'},
    ];
    final choices = teacherChoices({
      '1': {
        '1': [lessons],
      },
    }, (e) => resolvedTeacherName({}, e));
    expect(choices.length, 4);
    expect(choices.firstWhere((e) => e.id == 'a').lessons.length, 2);
  });
  test('기존 이름 설정은 충돌 없이 이전하며 다른 명단에 재사용하지 않는다', () async {
    final store = SchoolTeacherNames('school');
    await store.save('공수1', '김가', '김가람');
    final first = {'subject': '공수1', 'teacher': '김가*', 'teacherId': 'old:1'};
    var names = await store.migrate([first]);
    expect(resolvedTeacherName(names, first), '김가람');
    expect(resolvedTeacherName(names, {...first, 'subject': '공수2'}), '김가람');
    final reassigned = {...first, 'teacherId': 'new:1'};
    names = await store.migrate([reassigned]);
    expect(resolvedTeacherName(names, reassigned), '김가*');
    await store.save('@id:old:1', '김가*', '');
    names = await store.migrate([first]);
    expect(resolvedTeacherName(names, first), '김가*');
  });
  test('동명이인에게 기존 과목별 이름을 추측해서 배정하지 않는다', () async {
    final store = SchoolTeacherNames('school');
    await store.save('수학', '이혜', '이혜진');
    final a = {'subject': '수학', 'teacher': '이혜*', 'teacherId': 'a'};
    final b = {...a, 'teacherId': 'b'};
    final names = await store.migrate([a, b]);
    expect(resolvedTeacherName(names, a), '이혜*');
    expect(resolvedTeacherName(names, b), '이혜*');
  });
}
