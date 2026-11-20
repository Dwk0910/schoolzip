import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolzip/controls.dart';

void main() {
  testWidgets('page title remains readable above a fading scroll edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: CupertinoColors.black,
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(402, 874),
            padding: EdgeInsets.only(top: 62),
          ),
          child: RepaintBoundary(
            key: capture,
            child: CupertinoPageScaffold(
              child: LargeTitleScroll(
                title: '주간 시간표',
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
                children: [
                  for (var i = 0; i < 20; i++)
                    Container(
                      height: 70,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: const Color(0xff24242b),
                      child: Text(
                        '수업 내용 $i',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -230));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('주간 시간표').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('주간 시간표').hitTestable(), findsOneWidget);
  });
}
