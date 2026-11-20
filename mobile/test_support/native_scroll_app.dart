import 'package:flutter/services.dart';
import 'package:schoolzip/startup_timetable.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:schoolzip/native_home.dart';
import 'package:schoolzip/meals.dart';
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
  bool wide = false;

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
            'horizontal': wide,
            'periods': 20,
            'columns': [
              for (var i = 0; i < (wide ? 12 : 5); i++)
                {
                  'label': wide ? '${i + 1}반' : '월화수목금'[i],
                  'detail': '11/${16 + i}',
                  'badge': i == 0 ? '오늘' : null,
                  'highlighted': i == 0,
                },
            ],
            'cells': [
              for (var p = 1; p <= 20; p++)
                for (var c = 0; c < (wide ? 12 : 5); c++)
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
              if (mounted && value != null) {
                setState(() {
                  result = '선택 완료';
                  wide = true;
                });
              }
            }
          },
        ),
        MealPage(
          school: const {'name': '오남고등학교'},
          active: tab == 1,
          fetch: (_, _) async => <dynamic>[],
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
          schoolCode: 'ui-startup',
          onStartup: () async {
            final saved = await StartupTimetable.read('ui-startup');
            final result = await const MethodChannel('schoolzip/editors')
                .invokeMapMethod<String, dynamic>('startupTimetable', {
                  'mode': saved.mode.name,
                  'teacher': saved.teacher,
                  'label': saved.label,
                  'teachers': [
                    {'id': 'A', 'label': '김가람', 'subjects': '국어'},
                    {'id': 'B', 'label': '이가람', 'subjects': '수학'},
                  ],
                });
            if (result != null) {
              await StartupTimetable.fromJson(result).save('ui-startup');
            }
          },
          onTeachers: () {},
          onReset: () {},
          onGuide: () {},
        ),
      ],
    ),
  );
}
