import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:schoolzip/teacher_names.dart';
import 'package:schoolzip/teacher_sharing.dart';
import 'package:schoolzip/teacher_review.dart';

class FakeSharing extends TeacherSharing {
  List<Map<String, String>>? uploaded;
  FakeSharing() : super('school', '검증학교');
  @override
  Future<dynamic> request(
    String method, [
    List<Map<String, String>>? entries,
  ]) async {
    uploaded = entries;
    return {};
  }
}

const old = {
  'key': '@id:old:1',
  'teacherId': 'old:1',
  'original': '김가*',
  'subject': '공수1',
  'current': '김가람',
};
const current = {
  'key': '@id:new:1',
  'teacherId': 'new:1',
  'original': '김가*',
  'subject': '공수2',
  'current': '김가*',
};
void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test('명단 변경 후보는 이름과 과목 변경을 참고하고 자동 적용하지 않는다', () async {
    final store = SchoolTeacherNames('school');
    final sharing = FakeSharing();
    await store.save(old['key']!, old['original']!, '김가람');
    await sharing.remember([old]);
    await sharing.remember([current]);
    final before = await store.read();
    final options = await sharing.previous([current], before);
    expect(options.single['value'], '김가람');
    expect(teacherMatchScore(old, current), greaterThan(60));
    expect((await store.read())[current['key']], isNull);
    final after = await sharing.apply(options, store, shared: false);
    expect(after[current['key']]!['김가*'], '김가람');
    expect(after[old['key']]!['김가*'], '김가람');
    expect(await sharing.previous([current], after), isEmpty);
  });
  test('공유 이름 적용은 재투표되지 않고 직접 수정한 이름만 업로드된다', () async {
    final store = SchoolTeacherNames('school');
    final sharing = FakeSharing();
    final option = {
      'key': current['key']!,
      'original': '김가*',
      'value': '김가람',
      'source': 'shared:new:1',
    };
    var names = await sharing.apply([option], store, shared: true);
    await sharing.publish([current], names);
    expect(sharing.uploaded, isEmpty);
    names = await store.save(current['key']!, '김가*', '김가은');
    await sharing.publish([current], names);
    expect(sharing.uploaded!.single['value'], '김가은');
    await sharing.apply([option], store, shared: true);
    expect((await store.read())[current['key']]!['김가*'], '김가은');
  });
  test('가져온 이름은 명단 연결 후에도 새 입력 수로 재전파하지 않는다', () async {
    final store = SchoolTeacherNames('school');
    final sharing = FakeSharing();
    await sharing.apply(
      [
        {
          'key': old['key']!,
          'original': '김가*',
          'value': '김가람',
          'source': 'shared:old:1',
        },
      ],
      store,
      shared: true,
    );
    await sharing.remember([old]);
    final options = await sharing.previous([current], await store.read());
    final names = await sharing.apply(options, store, shared: false);
    await sharing.publish([current], names);
    expect(sharing.uploaded, isEmpty);
  });
  testWidgets('공유 후보는 미선택 상태이며 한 교사에 중복 선택할 수 없다', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: TeacherReviewPage(
          title: '공유 이름',
          options: [
            {
              'key': 'a',
              'source': 'shared:a',
              'original': '김가*',
              'value': '김가람',
              'title': '김가람 선생님',
              'detail': '1개 기기 · 미검증',
            },
            {
              'key': 'a',
              'source': 'shared:a',
              'original': '김가*',
              'value': '김가은',
              'title': '김가은 선생님',
              'detail': '1개 기기 · 미검증',
            },
            {
              'key': 'b',
              'source': 'shared:b',
              'original': '이가*',
              'value': '이가람',
              'title': '이가람 선생님',
              'detail': '1개 기기 · 미검증',
            },
          ],
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    await tester.tap(find.text('전체 해제'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
    await tester.tap(find.text('김가람 선생님'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('김가은 선생님'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });
}
