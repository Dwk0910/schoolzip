import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:schoolzip/controls.dart';
import 'package:schoolzip/home_tabs.dart';
import 'package:schoolzip/settings_page.dart';

void main() => runApp(
  const CupertinoApp(
    debugShowCheckedModeBanner: false,
    theme: CupertinoThemeData(
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    ),
    home: Smoke(),
  ),
);

class Smoke extends StatefulWidget {
  const Smoke({super.key});
  @override
  State<Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<Smoke> {
  int tab = 0;
  String result = '오남고등학교';
  Widget page(String title) => CupertinoPageScaffold(
    child: LargeTitleScroll(
      title: title,
      actionLabel: '학교 바꾸기',
      onAction: () => setState(() => result = '학교 선택 완료'),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
      children: [
        Text(result),
        CupertinoButton(
          onPressed: () => setState(() => result = '본문 터치 완료'),
          child: const Text('본문 버튼'),
        ),
        for (var i = 0; i < 25; i++)
          Container(
            height: 70,
            margin: const EdgeInsets.only(bottom: 8),
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            child: Text('수업 내용 $i', style: const TextStyle(fontSize: 24)),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => HomeTabsLayout(
    index: tab,
    onChanged: (i) => setState(() => tab = i),
    child: TabBody(
      index: tab,
      children: [
        page('주간 시간표'),
        page('급식 식단표'),
        SettingsPage(
          onAllergies: () {},
          allergyCount: 0,
          school: '오남고등학교',
          teachers: true,
          highlight: true,
          onDisplay: (_, _) {},
          room: '1학년 7반',
          onSchool: () {},
          onTeachers: () {},
          onReset: () {},
          onGuide: () {},
        ),
      ],
    ),
  );
}
