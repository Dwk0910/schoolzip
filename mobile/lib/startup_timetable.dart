import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_views.dart';

class StartupTimetable {
  final TimetableMode mode;
  final String? teacher, label;
  const StartupTimetable({
    this.mode = TimetableMode.mine,
    this.teacher,
    this.label,
  });
  factory StartupTimetable.fromJson(Map<String, dynamic> value) {
    final mode =
        TimetableMode.values
            .where((m) => m.name == value['mode'])
            .firstOrNull ??
        TimetableMode.mine;
    final teacher = value['teacher'] is String
        ? value['teacher'] as String
        : null;
    return StartupTimetable(
      mode: mode == TimetableMode.teachers && teacher == null
          ? TimetableMode.mine
          : mode,
      teacher: teacher,
      label: value['label'] is String ? value['label'] as String : null,
    );
  }
  static Future<StartupTimetable> read(String school) async {
    try {
      final raw = await SharedPreferencesAsync().getString(
        'startupTimetable:$school',
      );
      if (raw != null) {
        return StartupTimetable.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      /* Invalid old data must not prevent opening the timetable. */
    }
    return const StartupTimetable();
  }

  Future<void> save(String school) => SharedPreferencesAsync().setString(
    'startupTimetable:$school',
    jsonEncode({'mode': mode.name, 'teacher': teacher, 'label': label}),
  );
}

class StartupTimetablePage extends StatefulWidget {
  final StartupTimetable saved;
  final List<TeacherChoice> choices;
  const StartupTimetablePage({
    super.key,
    required this.saved,
    required this.choices,
  });
  @override
  State<StartupTimetablePage> createState() => _StartupTimetablePageState();
}

class _StartupTimetablePageState extends State<StartupTimetablePage> {
  late TimetableMode mode = widget.saved.mode;
  late String? teacher = widget.saved.teacher, label = widget.saved.label;
  String query = '';
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: const Text('앱 시작 시 시간표'),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed:
            mode == TimetableMode.teachers &&
                !widget.choices.any((c) => c.id == teacher)
            ? null
            : () => Navigator.pop(
                context,
                StartupTimetable(mode: mode, teacher: teacher, label: label),
              ),
        child: const Text('저장'),
      ),
    ),
    child: SafeArea(
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('시작할 보기 모드'),
            footer: const Text('다음 앱 실행부터 적용돼요. 사용 중 보기 모드를 바꿔도 이 설정은 유지돼요.'),
            children: [
              for (final item in TimetableMode.values)
                CupertinoListTile(
                  title: Text(item.label),
                  trailing: mode == item
                      ? const Icon(CupertinoIcons.check_mark)
                      : null,
                  onTap: () => setState(() => mode = item),
                ),
            ],
          ),
          if (mode == TimetableMode.teachers) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                placeholder: '선생님 이름 검색',
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            if (widget.choices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('선생님 명단을 불러오지 못했어요. 시간표를 새로고침한 뒤 다시 열어 주세요.'),
              ),
            for (final choice in widget.choices.where((c) => c.matches(query)))
              CupertinoListTile(
                title: Text('${choice.label} 선생님'),
                subtitle: Text(choice.subjects),
                trailing: teacher == choice.id
                    ? const Icon(CupertinoIcons.check_mark)
                    : null,
                onTap: () => setState(() {
                  teacher = choice.id;
                  label = choice.label;
                }),
              ),
          ],
        ],
      ),
    ),
  );
}
