import 'package:cupertino_ui/cupertino_ui.dart';

import 'controls.dart';
import 'timetable_grid.dart';

enum TimetableMode {
  mine('요일별 보기'),
  classes('학급별 보기'),
  teachers('선생님별 보기');

  final String label;
  const TimetableMode(this.label);
}

typedef SchoolLesson = ({
  String grade,
  String room,
  int day,
  Map<String, dynamic> lesson,
});

List<SchoolLesson> schoolLessons(Map<String, dynamic> grades) => [
  for (final grade in grades.entries)
    for (final room in (grade.value as Map).entries)
      for (var day = 0; day < (room.value as List).length; day++)
        for (final lesson in (room.value as List)[day])
          (
            grade: grade.key,
            room: room.key.toString(),
            day: day,
            lesson: Map<String, dynamic>.from(lesson),
          ),
];

int naturalOrder(String a, String b) =>
    (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0);

class ViewDropdown extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const ViewDropdown({super.key, required this.label, this.onPressed});
  @override
  Widget build(BuildContext context) => PressButton(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    ),
    onPressed: onPressed,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(CupertinoIcons.chevron_down, size: 14),
      ],
    ),
  );
}

Future<T?> chooseViewOption<T>(
  BuildContext context,
  String title,
  List<(T, String)> options,
  T selected,
) => showCupertinoModalPopup<T>(
  context: context,
  builder: (ctx) => CupertinoActionSheet(
    title: Text(title),
    actions: [
      for (final (value, label) in options)
        CupertinoActionSheetAction(
          isDefaultAction: value == selected,
          onPressed: () => Navigator.pop(ctx, value),
          child: Text(label),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(ctx),
      child: const Text('취소'),
    ),
  ),
);

const viewWeekdays = ['월', '화', '수', '목', '금', '토', '일'];
DateTime viewDate(DateTime start, int day) =>
    DateTime.utc(start.year, start.month, start.day + day);
String viewDateLabel(DateTime start, int day) {
  final date = viewDate(start, day);
  return '${date.month}/${date.day} (${viewWeekdays[date.weekday - 1]})';
}

class TeacherChoice {
  final String id, original, label, subjects;
  final List<SchoolLesson> lessons;
  const TeacherChoice(
    this.id,
    this.original,
    this.label,
    this.subjects,
    this.lessons,
  );
  bool matches(String query) => '$label $original $subjects'
      .toLowerCase()
      .contains(query.trim().toLowerCase());
}

List<TeacherChoice> teacherChoices(
  Map<String, dynamic> grades,
  String Function(Map<String, dynamic>) display,
) {
  final groups = <String, List<SchoolLesson>>{};
  for (final entry in schoolLessons(grades)) {
    final raw = (entry.lesson['teacher'] as String? ?? '').trim();
    if (raw.isEmpty) continue;
    // A masked name is not a unique person identifier across different subjects.
    final id =
        entry.lesson['teacherId'] as String? ??
        '${entry.lesson['subject']}\u0000$raw';
    (groups[id] ??= []).add(entry);
  }
  final result = [
    for (final group in groups.entries)
      TeacherChoice(
        group.key,
        (group.value.first.lesson['teacher'] as String).trim(),
        group.value
            .map((e) => display(e.lesson))
            .where((s) => s.isNotEmpty)
            .toSet()
            .join(' / '),
        group.value
            .map((e) => e.lesson['subject'].toString())
            .toSet()
            .join(' · '),
        group.value,
      ),
  ];
  result.sort((a, b) => a.label.compareTo(b.label));
  return result;
}

class TeacherPickerSheet extends StatefulWidget {
  final List<TeacherChoice> choices;
  final String? selected;
  const TeacherPickerSheet({super.key, required this.choices, this.selected});
  @override
  State<TeacherPickerSheet> createState() => _TeacherPickerSheetState();
}

class _TeacherPickerSheetState extends State<TeacherPickerSheet> {
  String query = '';
  late String? selected = widget.selected;
  @override
  Widget build(BuildContext context) {
    final options = widget.choices.where((e) => e.matches(query)).toList();
    return SelectionSheetFrame(
      title: '선생님 선택',
      immediate: true,
      child: Column(
        children: [
          CupertinoSearchTextField(
            placeholder: '이름 또는 과목 검색',
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: options.isEmpty
                ? const Center(child: Text('검색 결과가 없습니다'))
                : ListView(
                    children: [
                      for (final option in options)
                        CupertinoListTile(
                          title: Text('${option.label} 선생님'),
                          subtitle: Text(
                            option.label == option.original
                                ? option.subjects
                                : '${option.original} · ${option.subjects}',
                          ),
                          trailing: selected == option.id
                              ? const Icon(CupertinoIcons.check_mark, size: 18)
                              : null,
                          onTap: () => Navigator.pop(context, option.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class GradeDatePickerSheet extends StatefulWidget {
  final List<String> grades;
  final String grade;
  final int day;
  final DateTime start;
  const GradeDatePickerSheet({
    super.key,
    required this.grades,
    required this.grade,
    required this.day,
    required this.start,
  });
  @override
  State<GradeDatePickerSheet> createState() => _GradeDatePickerSheetState();
}

class _GradeDatePickerSheetState extends State<GradeDatePickerSheet> {
  late String grade = widget.grade;
  late int day = widget.day;
  @override
  Widget build(BuildContext context) => SelectionSheetFrame(
    title: '학년·날짜 선택',
    onApply: () => Navigator.pop(context, (grade, day)),
    child: Row(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final value in widget.grades)
                selection(
                  '$value학년',
                  value == grade,
                  () => setState(() => grade = value),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ListView(
            children: [
              for (var value = 0; value < 14; value++)
                selection(
                  viewDateLabel(widget.start, value),
                  value == day,
                  () => setState(() => day = value),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget selection(String label, bool active, VoidCallback onTap) =>
      PressButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        color: active
            ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
            : null,
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
}

class SelectionSheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onApply;
  final bool immediate;
  const SelectionSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.onApply,
    this.immediate = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.separator.resolveFrom(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .34,
                child: child,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: SheetCancelButton()),
                if (!immediate) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: PressButton(
                      color: CupertinoColors.systemIndigo,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      onPressed: onApply,
                      child: const Text(
                        '적용',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class TimetableOverview extends StatefulWidget {
  final TimetableMode mode;
  final Map<String, dynamic> grades;
  final String grade, room;
  final String? homeGrade;
  final DateTime start;
  final String Function(Map<String, dynamic>) teacherLabel;
  final bool showTeachers, highlight;
  final String? selectedTeacher;
  final int? selectedDay;
  final Future<void> Function(DateTime, int, Map<String, dynamic>) onChange;
  const TimetableOverview({
    super.key,
    this.selectedTeacher,
    this.homeGrade,
    this.selectedDay,
    this.highlight = true,
    required this.mode,
    required this.grades,
    required this.grade,
    required this.room,
    required this.start,
    required this.teacherLabel,
    required this.showTeachers,
    required this.onChange,
  });
  @override
  State<TimetableOverview> createState() => _TimetableOverviewState();
}

class _TimetableOverviewState extends State<TimetableOverview> {
  final horizontal = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacherMode = widget.mode == TimetableMode.teachers;
    final choices = teacherChoices(widget.grades, widget.teacherLabel);
    final chosen = choices
        .where((e) => e.id == widget.selectedTeacher)
        .firstOrNull;
    final active = widget.selectedTeacher == null
        ? choices.firstOrNull
        : chosen;
    final day = (widget.selectedDay ?? 0).clamp(0, 6);
    final rooms =
        (widget.grades[widget.grade] as Map).keys
            .map((e) => e.toString())
            .toList()
          ..sort(naturalOrder);
    final entries = teacherMode
        ? active?.lessons ?? <SchoolLesson>[]
        : schoolLessons(widget.grades)
              .where((e) => e.grade == widget.grade && e.day == day)
              .toList();
    final count = teacherMode
        ? entries
              .fold<int>(5, (n, e) => e.day + 1 > n ? e.day + 1 : n)
              .clamp(5, 7)
        : rooms.length;
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final today = DateTime.utc(now.year, now.month, now.day);
    final columns = [
      for (var i = 0; i < count; i++)
        GridColumn(
          teacherMode
              ? viewWeekdays[viewDate(widget.start, i).weekday - 1]
              : '${rooms[i]}반',
          teacherMode
              ? '${viewDate(widget.start, i).month}/${viewDate(widget.start, i).day}'
              : '${viewDate(widget.start, day).month}/${viewDate(widget.start, day).day}',
          today:
              teacherMode &&
              widget.highlight &&
              viewDate(widget.start, i) == today,
          badge:
              !teacherMode &&
                  widget.grade == widget.homeGrade &&
                  rooms[i] == widget.room
              ? '우리 반'
              : null,
          highlighted:
              widget.highlight &&
              (teacherMode
                  ? viewDate(widget.start, i) == today
                  : widget.grade == widget.homeGrade &&
                        rooms[i] == widget.room),
        ),
    ];
    final cells = <(int, int), List<GridLesson>>{};
    var periods = 0;
    for (final entry in entries) {
      final period = entry.lesson['period'] as int;
      if (period > periods) periods = period;
      final col = teacherMode ? entry.day : rooms.indexOf(entry.room);
      final changed = entry.lesson['changed'] == true;
      (cells[(col, period)] ??= []).add(
        GridLesson(
          subject: entry.lesson['subject'] as String? ?? '',
          secondary: teacherMode
              ? '${entry.grade}학년 ${entry.room}반'
              : widget.showTeachers
              ? widget.teacherLabel(entry.lesson)
              : '',
          changed: changed,
          semantics:
              '${entry.grade}학년 ${entry.room}반 ${viewWeekdays[entry.day]}요일 $period교시 ${entry.lesson['subject']}',
          onTap: changed
              ? () => widget.onChange(
                  viewDate(widget.start, entry.day),
                  period,
                  entry.lesson,
                )
              : null,
        ),
      );
    }
    if (cells.isEmpty) return const TimetableEmptyResult();
    Widget grid() =>
        TimetableGrid(columns: columns, cells: cells, periods: periods);
    if (teacherMode) return grid();
    return LayoutBuilder(
      builder: (ctx, box) => MediaQuery.removePadding(
        context: ctx,
        removeBottom: true,
        child: CupertinoScrollbar(
          controller: horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: (34 + rooms.length * 64.0).clamp(
                box.maxWidth,
                double.infinity,
              ),
              child: grid(),
            ),
          ),
        ),
      ),
    );
  }
}
