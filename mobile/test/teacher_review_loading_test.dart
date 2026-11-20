import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolzip/teacher_review.dart';

void main() {
  testWidgets('후보 응답 전에도 창과 로딩 표시를 보여준다', (tester) async {
    final response = Completer<List<Map<String, String>>>();
    await tester.pumpWidget(
      CupertinoApp(
        home: TeacherReviewLoader(
          title: '학교 공유 이름 확인',
          load: () => response.future,
        ),
      ),
    );
    expect(find.text('학교 공유 이름 확인'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    response.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(TeacherReviewPage), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });
  testWidgets('실패하면 창 안에서 재시도한다', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: TeacherReviewLoader(
          title: '학교 공유 이름 확인',
          load: () async {
            if (++attempts == 1) throw Exception('offline');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이름을 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherReviewPage), findsOneWidget);
    expect(attempts, 2);
  });
  testWidgets('창을 닫은 후 도착한 응답은 무시한다', (tester) async {
    final response = Completer<List<Map<String, String>>>();
    await tester.pumpWidget(
      CupertinoApp(
        home: TeacherReviewLoader(
          title: '학교 공유 이름 확인',
          load: () => response.future,
        ),
      ),
    );
    await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
    response.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
