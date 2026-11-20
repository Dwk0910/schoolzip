import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:schoolzip/native_home.dart';
import 'package:schoolzip/timetable_views.dart';
import 'package:schoolzip/home_tabs.dart';
import 'package:schoolzip/settings_page.dart';

void main() => runApp(
  const CupertinoApp(debugShowCheckedModeBanner: false, home: Smoke()),
);

class Smoke extends StatefulWidget {
  const Smoke({super.key});
  @override
  State<Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<Smoke> {
  int tab = 0;
  String result = '오남고등학교';

  @override
  Widget build(BuildContext context) => HomeTabsLayout(
    index: tab,
    onChanged: (i) => setState(() => tab = i),
    child: TabBody(
      index: tab,
      children: [
        NativePageModel(
          page: 'timetable',
          model: {
            'subtitle': result,
            'mode': '요일별 보기',
            'context': '1학년 7반',
            'showWeek': true,
            'week': 0,
            'status': 'ready',
            'horizontal': false,
            'periods': 20,
            'columns': [
              for (var i = 0; i < 5; i++)
                {
                  'label': '월화수목금'[i],
                  'detail': '11/${16 + i}',
                  'badge': i == 0 ? '오늘' : null,
                  'highlighted': i == 0,
                },
            ],
            'cells': [
              for (var p = 1; p <= 20; p++)
                for (var c = 0; c < 5; c++)
                  {
                    'column': c,
                    'period': p,
                    'lessons': [
                      {'subject': '국어', 'secondary': '김가람', 'changed': false},
                    ],
                  },
            ],
          },
          onAction: (action, _) async {
            if (action == 'school') setState(() => result = '학교 선택 완료');
            if (action == 'context') setState(() => result = '본문 터치 완료');
            if (action == 'mode') {
              final value = await chooseViewOption(context, '시간표 보기', [
                ('selected', '모드 선택 확인'),
              ], 'selected');
              if (mounted && value != null) setState(() => result = '선택 완료');
            }
          },
        ),
        NativePageModel(
          page: 'meals',
          model: {
            'subtitle': '오남고등학교',
            'date': '11월 20일 (금)',
            'status': 'empty',
            'showToday': false,
          },
          onAction: (_, _) {},
        ),
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
