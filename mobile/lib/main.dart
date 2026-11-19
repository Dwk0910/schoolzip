import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'widget_link.dart';
import 'week_cache.dart';
import 'home_tabs.dart';
import 'meals.dart';
import 'allergies.dart';
import 'settings_page.dart';
import 'teacher_names.dart';
import 'intro_guide.dart';

import 'controls.dart';
import 'sheets.dart';
import 'planner_illustration.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;

import 'package:cupertino_ui/cupertino_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Schoolzip());
}

typedef LaunchState = ({
  Map<String, dynamic>? saved,
  bool showGuide,
  bool teachers,
  bool highlight,
  Set<int> allergies,
});

// An immediate failure can arrive before the next frame attaches FutureBuilder.
// Keep the original future (and its error) available to the result screen.
Future<T> _forNextBuild<T>(Future<T> future) {
  future.ignore();
  return future;
}

Future<LaunchState> readLaunchState() async {
  final values = await SharedPreferencesAsync().getAll(
    allowList: {
      'selectedClass',
      'guideSeen',
      'showTeachers',
      'highlightToday',
      'allergies',
    },
  );
  Map<String, dynamic>? saved;
  final raw = values['selectedClass'];
  if (raw is String) {
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['code'] is int &&
          value['name'] is String &&
          value['grade'] is String &&
          value['room'] is String) {
        saved = value;
      }
    } on FormatException {
      // A damaged selection can be replaced during setup.
    }
  }
  unawaited(syncWidget(saved));
  return (
    allergies: ((values['allergies'] as List?) ?? [])
        .whereType<String>()
        .map(int.tryParse)
        .whereType<int>()
        .where((v) => v > 0 && v < allergenNames.length)
        .toSet(),
    saved: saved,
    teachers: values['showTeachers'] != false,
    highlight: values['highlightToday'] != false,
    showGuide: values['guideSeen'] != true,
  );
}

class Schoolzip extends StatefulWidget {
  const Schoolzip({super.key});
  @override
  State<Schoolzip> createState() => _SchoolzipState();
}

class _SchoolzipState extends State<Schoolzip> {
  late Future<LaunchState> initial = _forNextBuild(readLaunchState());
  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'school.zip',
    debugShowCheckedModeBanner: false,
    theme: const CupertinoThemeData(
      primaryColor: CupertinoColors.systemIndigo,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    ),
    home: FutureBuilder<LaunchState>(
      future: initial,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError) {
          return CupertinoPageScaffold(
            child: ErrorResult(
              icon: CupertinoIcons.folder,
              title: '앱 설정을 열지 못했어요',
              description: '이 기기에 저장한 학교와 학급 설정을 다시 불러올 수 있어요.',
              onRetry: () =>
                  setState(() => initial = _forNextBuild(readLaunchState())),
            ),
          );
        }
        final state = snapshot.data;
        if (state == null) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return SchoolHome(
          saved: state.saved,
          showGuide: state.showGuide,
          allergies: state.allergies,
          teachers: state.teachers,
          highlight: state.highlight,
        );
      },
    ),
  );
}

final _apiClient = HttpClient()..connectionTimeout = const Duration(seconds: 8);
var _weeks = WeekCache((uri) => _fetchJson(uri, timetable: true));

Future<dynamic> request(String path, Map<String, String> query) {
  final uri = Uri.parse('$timetableBaseUrl/api/$path')
      .replace(queryParameters: query);
  return path == 'timetable' ? _weeks.get(uri) : _fetchJson(uri);
}

Future<dynamic> _fetchJson(Uri uri, {bool timetable = false}) async {
  final req = await _apiClient.getUrl(uri);
  final res = await req.close().timeout(const Duration(seconds: 35));
  if (res.statusCode != 200) {
    await res.drain<void>();
    throw HttpException('HTTP ${res.statusCode}');
  }
  final body = await utf8.decoder.bind(res).join();
  return timetable ? compute(jsonDecode, body) : jsonDecode(body);
}

class SchoolHome extends StatefulWidget {
  final Future<dynamic> Function(String, Map<String, String>) fetch;
  final Map<String, dynamic>? saved;
  final bool showGuide, teachers, highlight;
  final Set<int> allergies;
  const SchoolHome({
    this.allergies = const {},
    super.key,
    this.fetch = request,
    this.saved,
    this.showGuide = false,
    this.teachers = true,
    this.highlight = true,
  });
  @override
  State<SchoolHome> createState() => _SchoolHomeState();
}

class _SchoolHomeState extends State<SchoolHome> {
  late Map<String, dynamic>? school = widget.saved, preferred = widget.saved;
  late Set<int> allergies = widget.allergies;
  Future<void> editAllergies() async {
    final result = await Navigator.push<Set<int>>(
      context,
      CupertinoPageRoute(builder: (_) => AllergyPicker(selected: allergies)),
    );
    if (result == null || !mounted) return;
    await SharedPreferencesAsync().setStringList('allergies', [
      for (final code in result) code.toString(),
    ]);
    if (mounted) setState(() => allergies = result);
  }

  late bool teachers = widget.teachers, highlight = widget.highlight;
  Future<void> changeDisplay(String key, bool value) async {
    await SharedPreferencesAsync().setBool(key, value);
    if (mounted) {
      setState(() {
        if (key == 'showTeachers') {
          teachers = value;
        } else {
          highlight = value;
        }
      });
    }
  }

  late bool showGuide = widget.showGuide;
  Future<void> dismissGuide() async {
    await SharedPreferencesAsync().setBool('guideSeen', true);
    if (mounted) setState(() => showGuide = false);
  }

  Future<void> remember(
    Map<String, dynamic> selected,
    String grade,
    String room,
  ) async {
    final value = {...selected, 'grade': grade, 'room': room};
    await SharedPreferencesAsync().setString(
      'selectedClass',
      jsonEncode(value),
    );
    await syncWidget(value);
    if (mounted) {
      setState(() => preferred = value);
    }
  }

  var weeklyKey = GlobalKey<_WeeklyPageState>();
  int resetCount = 0;
  Future<void> resetAll() async {
    final confirmed = await showSchoolSheet<bool>(
      context: context,
      draggable: true,
      builder: (_) => const ResetSheet(),
    );
    if (!mounted || confirmed != true) return;
    try {
      await resetWidget();
      await SharedPreferencesAsync().clear();
      _weeks = WeekCache((uri) => _fetchJson(uri, timetable: true));
      if (mounted) {
        setState(() {
          teachers = true;
          highlight = true;
          allergies = {};
          resetCount++;
          tab = 0;
          school = null;
          preferred = null;
          setupWeek = null;
          showGuide = true;
        });
      }
    } catch (_) {
      if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('초기화하지 못했어요'),
            content: const Text('다시 시도해 주세요.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  int tab = 0;
  Future<dynamic>? setupWeek;

  void select(Map<String, dynamic> result, [Future<dynamic>? week]) =>
      setState(() {
        tab = 0;
        if (school?['code'] != result['code']) {
          weeklyKey = GlobalKey<_WeeklyPageState>();
        }
        school = result;
        setupWeek = week;
      });
  Future<void> changeSchool() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(
        builder: (ctx) => SchoolSearch(
          fetch: widget.fetch,
          saved: preferred,
          onSelect: (s) => Navigator.of(ctx).pop(s),
        ),
      ),
    );
    if (mounted && result != null) {
      select(result);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    key: ValueKey(resetCount),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 440),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) {
      final isSetup = child is SetupFlow;
      // The timetable covers the setup page as it moves in.
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(isSetup ? -.22 : 1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
    child: school == null
        ? SetupFlow(fetch: widget.fetch, remember: remember, onComplete: select)
        : HomeTabsLayout(
            index: tab,
            onChanged: (value) => setState(() => tab = value),
            child: TabBody(
              index: tab,
              children: [
                WeeklyPage(
                  key: weeklyKey,
                  teachers: teachers,
                  highlight: highlight,
                  school: school!,
                  initialWeek: setupWeek,
                  onGuideFinished: showGuide ? dismissGuide : null,
                  preferred: preferred?['code'] == school!['code']
                      ? preferred
                      : null,
                  fetch: widget.fetch,
                  remember: remember,
                  changeSchool: changeSchool,
                ),
                MealPage(
                  allergies: allergies,
                  key: ValueKey(school!['code']),
                  school: school!,
                  active: tab == 1,
                  fetch: widget.fetch,
                ),
                SettingsPage(
                  onAllergies: editAllergies,
                  allergyCount: allergies.length,
                  teachers: teachers,
                  highlight: highlight,
                  onDisplay: changeDisplay,
                  school: school!['name'],
                  room: preferred?['code'] == school!['code']
                      ? "${preferred!['grade']}학년 ${preferred!['room']}반"
                      : '',
                  onSchool: changeSchool,
                  onTeachers: () => weeklyKey.currentState?.openTeachers(),
                  onReset: resetAll,
                ),
              ],
            ),
          ),
  );
}

class SetupFlow extends StatefulWidget {
  final Future<dynamic> Function(String, Map<String, String>) fetch;
  final Future<void> Function(Map<String, dynamic>, String, String) remember;
  final void Function(Map<String, dynamic>, Future<dynamic>) onComplete;
  const SetupFlow({
    super.key,
    required this.fetch,
    required this.remember,
    required this.onComplete,
  });
  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  final pages = PageController();
  Map<String, dynamic>? selected;
  Future<dynamic>? table;
  int step = 0;
  bool saving = false, complete = false;
  String? saveError;

  Future<dynamic> load(Map<String, dynamic> school) => widget.fetch(
    'timetable',
    {'name': school['name'], 'code': school['code'].toString(), 'week': '0'},
  );

  void go(int page) {
    setState(() => step = page);
    if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(page);
    } else {
      pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  int? preparedCode;
  DateTime? preparedAt;
  Future<dynamic>? prepared;

  Future<dynamic> prepare(Map<String, dynamic> school) {
    final now = DateTime.now();
    if (prepared != null &&
        preparedCode == school['code'] &&
        now.difference(preparedAt!).inSeconds < 90) {
      return prepared!;
    }
    preparedCode = school['code'];
    preparedAt = now;
    final result = load(school);
    prepared = result;
    result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (identical(prepared, result)) prepared = null;
      },
    );
    return result;
  }

  void choose(Map<String, dynamic> school) {
    if (step != 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    selected = school;
    table = prepare(school);
    saveError = null;
    go(1);
  }

  Future<void> finish(String grade, String room) async {
    if (saving || step != 1) return;
    final school = selected!;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.remember(school, grade, room);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          saveError = '저장하지 못했어요. 다시 눌러 주세요.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => complete = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(SetupProgress.duration);
    }
    if (mounted) widget.onComplete(school, table!);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: step == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && step == 1 && !saving) go(0);
    },
    child: CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('스쿨집 시작하기'),
        leading: step == 1 && !saving
            ? CupertinoNavigationBarBackButton(
                previousPageTitle: '학교',
                onPressed: () => go(0),
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: SetupProgress(step: step, complete: complete),
            ),
            Expanded(
              child: PageView(
                controller: pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SchoolSearch(
                    fetch: widget.fetch,
                    firstRun: true,
                    onSelect: choose,
                    onSingleResult: prepare,
                  ),
                  if (selected == null)
                    const SizedBox.shrink()
                  else
                    FutureBuilder<dynamic>(
                      key: ValueKey(selected!['code']),
                      future: table,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClassHeading(school: selected!['name']),
                                const SizedBox(height: 12),
                                const SelectionLoading(),
                              ],
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return ErrorResult(
                            icon: CupertinoIcons.person_2,
                            title: '학급 목록을 불러오지 못했어요',
                            description:
                                "${selected!['name']}의 학년과 반을 다시 불러올 수 있어요.",
                            onRetry: () => setState(
                              () => table = _forNextBuild(load(selected!)),
                            ),
                          );
                        }
                        final grades =
                            snapshot.data['grades'] as Map<String, dynamic>;
                        final rooms = {
                          for (final g in grades.entries)
                            if ((g.value as Map).isNotEmpty)
                              g.key: (g.value as Map<String, dynamic>).keys
                                  .toList(),
                        };
                        if (rooms.isEmpty) {
                          return const Center(child: Text('등록된 시간표가 없어요.'));
                        }
                        final grade = rooms.keys.first;
                        return ClassPicker(
                          rooms: rooms,
                          grade: grade,
                          room: rooms[grade]!.first,
                          schoolName: selected!['name'],
                          onConfirm: finish,
                          saving: saving,
                          saveError: saveError,
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SchoolSearch extends StatefulWidget {
  final Future<dynamic> Function(String, Map<String, String>) fetch;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final Map<String, dynamic>? saved;
  final bool firstRun;
  final ValueChanged<Map<String, dynamic>>? onSingleResult;
  const SchoolSearch({
    this.firstRun = false,
    this.onSingleResult,
    super.key,
    required this.fetch,
    required this.onSelect,
    this.saved,
  });
  @override
  State<SchoolSearch> createState() => _SchoolSearchState();
}

class _SchoolSearchState extends State<SchoolSearch>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.firstRun;
  final input = TextEditingController();
  final focus = FocusNode();
  Future<List<dynamic>>? results;
  String submitted = '';
  @override
  void initState() {
    super.initState();
    focus.addListener(refresh);
    input.addListener(refresh);
  }

  void refresh() {
    setState(() {
      if (input.text.trim() != submitted) {
        results = null;
      }
    });
  }

  void search() {
    final q = input.text.trim();
    if (q.isEmpty) {
      focus.requestFocus();
      return;
    }
    focus.unfocus();
    setState(() {
      submitted = q;
      results = _forNextBuild(
        widget.fetch('schools', {'q': q}).then((v) {
          final schools = v as List<dynamic>;
          if (mounted && input.text.trim() == q && schools.length == 1) {
            widget.onSingleResult?.call(schools.single as Map<String, dynamic>);
          }
          return schools;
        }),
      );
    });
  }

  @override
  void dispose() {
    input.removeListener(refresh);
    focus.removeListener(refresh);
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final editing = focus.hasFocus || input.text.isNotEmpty;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final resultList = FutureBuilder<List<dynamic>>(
      future: results,
      builder: (context, snapshot) {
        if (results == null) {
          return const SizedBox.shrink();
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SelectionLoading();
        }
        if (snapshot.hasError) {
          return ErrorResult(
            icon: CupertinoIcons.search,
            title: '학교를 검색하지 못했어요',
            description: '입력한 학교 이름으로 다시 검색할 수 있어요.',
            onRetry: search,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Text('검색 결과가 없어요.');
        }
        return ListView.builder(
          itemCount: items.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
                child: Text(
                  '검색 결과 ${items.length}곳',
                  style: TextStyle(color: secondary, fontSize: 14),
                ),
              );
            }
            final school = items[i - 1] as Map<String, dynamic>;
            final current = school['code'] == widget.saved?['code'];
            final name = school['name'] as String;
            final kind = [
              '고등학교',
              '중학교',
              '초등학교',
            ].where(name.endsWith).firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: panel(
                ctx,
                PressButton(
                  padding: const EdgeInsets.symmetric(
                    vertical: 19,
                    horizontal: 16,
                  ),
                  onPressed: () {
                    focus.unfocus();
                    widget.onSelect(school);
                  },
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.book, size: 23),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label.resolveFrom(ctx),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              [
                                school['region'],
                                ?kind,
                                if (current)
                                  "저장된 ${widget.saved!['grade']}학년 ${widget.saved!['room']}반",
                              ].join(' · '),
                              style: TextStyle(fontSize: 13, color: secondary),
                            ),
                          ],
                        ),
                      ),
                      const CupertinoListTileChevron(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    final introduction = Align(
      alignment: Alignment.bottomCenter,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CustomPaint(
                size: Size(180, 100),
                painter: PlannerIllustration(),
              ),
              const SizedBox(height: 10),
              Text(
                widget.firstRun ? '학교생활을 한곳에' : '우리 학교 시간표',
                style: titleStyle,
              ),
              const SizedBox(height: 6),
              Text(
                widget.firstRun
                    ? '먼저 다니는 학교와 반을 선택해 주세요.'
                    : '학교를 찾고 우리 반의 한 주를 확인하세요.',
                style: TextStyle(color: secondary, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final resting = (box.maxHeight * .48).clamp(0.0, box.maxHeight);
          return TweenAnimationBuilder<double>(
            tween: Tween(end: editing ? 1.0 : 0.0),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, t, field) {
              final top = resting * (1 - t) + 12 * t;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: top,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        excluding: editing,
                        child: Opacity(opacity: 1 - t, child: introduction),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top,
                    bottom: 0,
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: selectionHeaderConstraints,
                          child: field!,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: keyboard.clamp(
                                0.0,
                                (box.maxHeight - top - 78).clamp(
                                  0.0,
                                  box.maxHeight,
                                ),
                              ),
                            ),
                            child: resultList,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: input,
                    focusNode: focus,
                    textInputAction: TextInputAction.search,
                    placeholder: '학교 이름',
                    clearButtonMode: OverlayVisibilityMode.editing,
                    onSubmitted: (_) => search(),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Icon(
                        CupertinoIcons.search,
                        size: 20,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemGroupedBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PressButton(
                  color: CupertinoColors.systemIndigo,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  onPressed: search,
                  child: const Text(
                    '검색',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (widget.firstRun) return body;
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('school.zip'),
        previousPageTitle: '시간표',
      ),
      child: SafeArea(child: body),
    );
  }
}

const titleStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w700,
  letterSpacing: -1.2,
);
Widget panel(BuildContext context, Widget child) => Container(
  decoration: BoxDecoration(
    color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    ),
    borderRadius: BorderRadius.circular(22),
  ),
  clipBehavior: Clip.antiAlias,
  child: child,
);

class ErrorResult extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final VoidCallback onRetry;

  const ErrorResult({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(icon, color: accent, size: 29),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    letterSpacing: -.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 18),
              PressButton(
                onPressed: onRetry,
                color: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklyPage extends StatefulWidget {
  final Map<String, dynamic> school;
  final Future<dynamic> Function(String, Map<String, String>) fetch;
  final Map<String, dynamic>? preferred;
  final Future<void> Function(Map<String, dynamic>, String, String) remember;
  final VoidCallback changeSchool;
  final Future<dynamic>? initialWeek;
  final Future<void> Function()? onGuideFinished;
  final bool teachers, highlight;
  const WeeklyPage({
    this.teachers = true,
    this.highlight = true,
    this.onGuideFinished,
    this.initialWeek,
    required this.changeSchool,
    super.key,
    required this.school,
    required this.fetch,
    required this.preferred,
    required this.remember,
  });
  @override
  State<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends State<WeeklyPage> with WidgetsBindingObserver {
  Timer? midnight;
  DateTime today = schoolDate();
  static DateTime schoolDate() {
    final local = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime.utc(local.year, local.month, local.day);
  }

  void scheduleDate() {
    midnight?.cancel();
    final date = schoolDate();
    if (date != today) {
      setState(() => today = date);
    }
    final next = date
        .add(const Duration(days: 1))
        .subtract(const Duration(hours: 9));
    midnight = Timer(next.difference(DateTime.now().toUtc()), scheduleDate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      scheduleDate();
    }
  }

  @override
  void dispose() {
    midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int week = 0;
  late String? grade = widget.preferred?['grade'];
  late String? room = widget.preferred?['room'];
  late Future<dynamic> data;
  Map<String, dynamic>? offlineWeek;
  DateTime? timetableMonday;

  late final nameStore = SchoolTeacherNames(widget.school['code'].toString());
  TeacherNames teacherNames = {};

  Future<void> loadTeacherNames() async {
    try {
      final saved = await nameStore.read();
      if (!mounted) return;
      setState(() => teacherNames = saved);
      await syncTeacherNames(nameStore.code, saved);
    } catch (error) {
      debugPrint('Teacher name read failed: $error');
    }
  }

  String displayTeacher(Map<String, dynamic> lesson) {
    final original = (lesson['teacher'] as String?)?.trim() ?? '';
    return teacherNames[lesson['subject']]?[original] ?? original;
  }

  Future<void> openTeachers() async {
    var source = data;
    await Navigator.push<void>(
      context,
      CupertinoPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (ctx, refresh) {
            return CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(
                middle: Text('선생님 이름 설정'),
              ),
              child: SafeArea(
                child: FutureBuilder<dynamic>(
                  future: source,
                  builder: (_, snap) {
                    final table = snap.data ?? offlineWeek;
                    if (table == null && snap.hasError) {
                      return ErrorResult(
                        icon: CupertinoIcons.person_2,
                        title: '선생님 목록을 불러오지 못했어요',
                        description: '시간표를 다시 불러와 주세요.',
                        onRetry: () =>
                            refresh(() => source = _forNextBuild(load())),
                      );
                    }
                    if (table == null) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final entries = <(String, String)>{
                      for (final subject in teacherNames.entries)
                        for (final name in subject.value.keys)
                          (subject.key, name),
                    };
                    for (final rooms in (table['grades'] as Map).values) {
                      for (final days in (rooms as Map).values) {
                        for (final day in days) {
                          for (final lesson in day) {
                            for (final item in [lesson, lesson['original']]) {
                              final subject = item?['subject'] as String? ?? '';
                              final name = (item?['teacher'] as String? ?? '')
                                  .trim();
                              if (subject.isNotEmpty && name.isNotEmpty) {
                                entries.add((subject, name));
                              }
                            }
                          }
                        }
                      }
                    }
                    final sorted = entries.toList()
                      ..sort((a, b) {
                        final cmp = a.$1.compareTo(b.$1);
                        return cmp == 0 ? a.$2.compareTo(b.$2) : cmp;
                      });
                    if (sorted.isEmpty) {
                      return const Center(child: Text('등록된 선생님이 없어요'));
                    }
                    return ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (_, i) {
                        final (subject, name) = sorted[i];
                        final lesson = {'subject': subject, 'teacher': name};
                        return CupertinoListTile(
                          title: Text(subject),
                          additionalInfo: Text(displayTeacher(lesson)),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () async {
                            await editTeacher(lesson);
                            if (ctx.mounted) refresh(() {});
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> editTeacher(Map<String, dynamic> lesson) async {
    final subject = lesson['subject'] as String;
    final original = (lesson['teacher'] as String).trim();
    await showSchoolSheet<void>(
      context: context,
      builder: (_) => TeacherNameEditor(
        subject: subject,
        original: original,
        current: displayTeacher(lesson),
        onSave: (value) async {
          final updated = await nameStore.save(subject, original, value);
          if (mounted) setState(() => teacherNames = updated);
          unawaited(syncTeacherNames(nameStore.code, updated));
        },
      ),
    );
  }

  String get currentMonday => today
      .subtract(Duration(days: today.weekday - 1))
      .toIso8601String()
      .substring(0, 10);

  Future<void> readSnapshot() async {
    try {
      final raw = await SharedPreferencesAsync().getString('lastWeek');
      if (!mounted || raw == null || offlineWeek != null) return;
      final stored = await compute(jsonDecode, raw);
      if (!mounted ||
          offlineWeek != null ||
          stored is! Map ||
          stored['code'] != widget.school['code']) {
        return;
      }
      final cached = stored['table'];

      if (cached is Map<String, dynamic> &&
          cached['start'] == currentMonday &&
          cached['grades'] is Map<String, dynamic>) {
        setState(() => offlineWeek = cached);
      }
    } catch (error) {
      debugPrint('Weekly cache read failed: $error');
    }
  }

  Future<void> saveSnapshot(Map<String, dynamic> table) async {
    try {
      final raw = await compute(jsonEncode, {
        'code': widget.school['code'],
        'table': table,
      });
      if (mounted && identical(offlineWeek, table)) {
        await SharedPreferencesAsync().setString('lastWeek', raw);
      }
    } catch (error) {
      debugPrint('Weekly cache write failed: $error');
    }
  }

  Future<dynamic> load([Future<dynamic>? initialWeek]) async {
    final requestedWeek = week;
    final table =
        await (initialWeek ??
            widget.fetch('timetable', {
              'name': widget.school['name'],
              'code': widget.school['code'].toString(),
              'week': requestedWeek.toString(),
            }));
    if (mounted && week == requestedWeek) {
      timetableMonday = DateTime.parse(table['start'])
          .subtract(Duration(days: 7 * requestedWeek));
    }
    if (mounted &&
        requestedWeek == 0 &&
        widget.preferred != null &&
        !identical(offlineWeek, table)) {
      offlineWeek = table as Map<String, dynamic>;
      unawaited(saveSnapshot(offlineWeek!));
    }
    if (mounted &&
        requestedWeek == 0 &&
        Platform.isAndroid &&
        widget.preferred != null) {
      final saved = widget.preferred!;
      final days = table['grades']?[saved['grade']]?[saved['room']];
      if (days is List) {
        unawaited(publishWidgetWeek(saved, table['start'], days));
      }
    }
    return table;
  }

  @override
  void initState() {
    super.initState();
    unawaited(loadTeacherNames());
    WidgetsBinding.instance.addObserver(this);
    scheduleDate();
    if (widget.initialWeek == null && widget.preferred != null) {
      unawaited(readSnapshot());
    }
    data = _forNextBuild(load(widget.initialWeek));
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, Platform.isIOS ? 24 : 90),
        children: [
          const Text('주간 시간표', style: titleStyle),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.school['name'],
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
              PressButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: widget.changeSchool,
                child: const Text(
                  '학교 바꾸기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WeekControl(
            value: week,
            onChanged: (value) {
              if (value != week) {
                setState(() {
                  week = value;
                  data = _forNextBuild(load());
                });
              }
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<dynamic>(
            future: data,
            builder: (context, snapshot) {
              final cached = week == 0 && offlineWeek?['start'] == currentMonday
                  ? offlineWeek
                  : null;
              if (cached == null &&
                  snapshot.connectionState != ConnectionState.done) {
                final previous = snapshot.data ?? offlineWeek;
                final previousGrades =
                    previous?['grades'] as Map<String, dynamic>?;
                final available = previousGrades?.keys.where(
                  (key) => previousGrades[key].isNotEmpty,
                );
                final g = (available?.contains(grade) ?? false)
                    ? grade
                    : available?.firstOrNull ?? grade;
                final rooms =
                    (previousGrades?[g] as Map<String, dynamic>?)?.keys;
                final c = (rooms?.contains(room) ?? false)
                    ? room
                    : rooms?.firstOrNull ?? room;
                final start = (timetableMonday ?? DateTime.parse(currentMonday))
                    .add(Duration(days: 7 * week));
                final previousDays = previousGrades?[g]?[c] as List?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (g != null && c != null) classLabelButton(g, c),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        week == 0 ? '이번 주 시간표' : '다음 주 시간표',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                    weekGrid(
                      start,
                      List.filled(previousDays?.length ?? 5, const []),
                      loading: true,
                    ),
                  ],
                );
              }
              if (cached == null && snapshot.hasError) {
                return ErrorResult(
                  icon: CupertinoIcons.calendar,
                  title: week == 0
                      ? '이번 주 시간표를 불러오지 못했어요'
                      : '다음 주 시간표를 불러오지 못했어요',
                  description: '잠시 후 다시 시도해 주세요.',
                  onRetry: () => setState(() {
                    data = _forNextBuild(load());
                  }),
                );
              }
              final table =
                  snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData
                  ? snapshot.data
                  : cached!;
              final grades = table['grades'] as Map<String, dynamic>;
              final available = grades.keys
                  .where((g) => grades[g].isNotEmpty)
                  .toList();
              if (available.isEmpty) {
                return const Text('등록된 시간표가 없어요.');
              }
              final g = available.contains(grade) ? grade! : available.first;
              final rooms = (grades[g] as Map<String, dynamic>).keys.toList();
              final c = rooms.contains(room) ? room! : rooms.first;
              final days = grades[g][c] as List<dynamic>;
              final start = DateTime.parse(table['start']);
              final classButton = classPicker(grades, available, g, c);
              if (week == 0) queueGuide();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  classButton,
                  if (snapshot.hasError)
                    PressButton(
                      onPressed: () =>
                          setState(() => data = _forNextBuild(load())),
                      child: const Text('저장된 시간표 · 다시 불러오기'),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "컴시간 갱신 · ${table['updated']}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                  weekGrid(start, days),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  bool guideScheduled = false;

  void queueGuide() {
    final finish = widget.onGuideFinished;
    if (finish == null ||
        widget.preferred == null ||
        guideScheduled ||
        ModalRoute.isCurrentOf(context) != true) {
      return;
    }
    guideScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.initialWeek != null &&
          !MediaQuery.disableAnimationsOf(context)) {
        await Future<void>.delayed(const Duration(milliseconds: 440));
      }
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true ||
          widget.onGuideFinished == null) {
        guideScheduled = false;
        return;
      }
      await showSchoolSheet<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => IntroGuide(
          classButton: classLabelButton(GuideExample.grade, GuideExample.room),
          grid: weekGrid(
            GuideExample.monday,
            GuideExample.days,
            maxRows: 2,
            highlightDate: GuideExample.monday,
            preview: true,
          ),
          weekHeader: weekGrid(
            GuideExample.monday,
            GuideExample.days,
            maxRows: 0,
            highlightDate: GuideExample.monday,
            preview: true,
          ),
          onFinish: () async {
            await finish();
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      );
    });
  }

  Widget classPicker(
    Map<String, dynamic> grades,
    List<String> available,
    String g,
    String c,
  ) {
    return classLabelButton(
      g,
      c,
      onPressed: () async {
        final result = await showSchoolSheet<(String, String)>(
          draggable: true,
          context: context,
          builder: (_) => ClassPicker(
            grade: g,
            room: c,
            rooms: {
              for (final key in available)
                key: (grades[key] as Map<String, dynamic>).keys.toList(),
            },
          ),
        );
        if (mounted && result != null) {
          try {
            await widget.remember(widget.school, result.$1, result.$2);
          } catch (_) {
            if (mounted) {
              await showCupertinoDialog<void>(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('학년·반을 저장하지 못했어요'),
                  content: const Text('잠시 후 다시 적용해 주세요.'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
          if (!mounted) return;
          setState(() {
            grade = result.$1;
            room = result.$2;
          });
        }
      },
    );
  }

  Widget classLabelButton(String g, String c, {VoidCallback? onPressed}) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: PressButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
            context,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$g학년 $c반',
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_down, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showLessonChange(
    DateTime date,
    int period,
    Map<String, dynamic> lesson,
  ) async {
    final original = lesson['original'] as Map<String, dynamic>?;
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];
    await showSchoolSheet<void>(
      context: context,
      builder: (ctx) {
        final secondary = CupertinoColors.secondaryLabel.resolveFrom(ctx);
        return Dismissible(
          key: const ValueKey('lesson-change-sheet'),
          direction: DismissDirection.down,
          dismissThresholds: const {DismissDirection.down: .25},
          resizeDuration: null,
          onDismissed: (_) => Navigator.pop(ctx),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(ctx),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey4.resolveFrom(ctx),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${date.month}월 ${date.day}일 ($weekday) · $period교시',
                            style: TextStyle(fontSize: 14, color: secondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '수업 변경',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LessonChangeRows(
                            original: original,
                            lesson: lesson,
                            teacherLabel: displayTeacher,
                          ),
                          const SizedBox(height: 8),
                          PressButton(
                            onPressed: () => Navigator.pop(ctx),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            color: CupertinoColors.systemIndigo.resolveFrom(
                              ctx,
                            ),
                            child: const Text(
                              '닫기',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget weekGrid(
    DateTime start,
    List<dynamic> days, {
    int? maxRows,
    bool loading = false,
    bool preview = false,
    DateTime? highlightDate,
  }) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    final slots = <(int, int), dynamic>{};
    var lastPeriod = 0;
    for (var day = 0; day < days.length; day++) {
      for (final lesson in days[day]) {
        final period = lesson['period'] as int;
        slots[(day, period)] = lesson;
        if (period > lastPeriod) {
          lastPeriod = period;
        }
      }
    }
    if (maxRows != null && lastPeriod > maxRows) lastPeriod = maxRows;
    final markedDay = highlightDate ?? (widget.highlight ? today : null);
    final count = days.length.clamp(5, 7);
    final dates = List.generate(
      count,
      (i) => DateTime.utc(start.year, start.month, start.day + i),
    );
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    final tint = accent.withValues(alpha: 0.12);
    const periodWidth = 34.0;
    return Column(
      children: [
        if (dates.contains(markedDay))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                const SizedBox(width: periodWidth),
                for (final date in dates)
                  Expanded(
                    child: Center(
                      child: date == markedDay
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                child: Text(
                                  '오늘',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        panel(
          context,
          Column(
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(width: periodWidth),
                        for (final date in dates)
                          Expanded(
                            child: ColoredBox(
                              color: date == markedDay
                                  ? accent.withValues(alpha: 0.09)
                                  : const Color(0x00000000),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Table(
                    columnWidths: const {0: FixedColumnWidth(periodWidth)},
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder.symmetric(
                      inside: BorderSide(
                        width: 0.5,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: tint),
                        children: [
                          const Center(
                            child: Text('교시', style: TextStyle(fontSize: 11)),
                          ),
                          for (final date in dates)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Column(
                                children: [
                                  Text(
                                    names[date.weekday - 1],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                  Text(
                                    '${date.month}/${date.day}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      for (var period = 1; period <= lastPeriod; period++)
                        TableRow(
                          children: [
                            Center(
                              child: Text(
                                '$period',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            for (var day = 0; day < count; day++)
                              Builder(
                                builder: (context) {
                                  final lesson = slots[(day, period)];
                                  final changed = lesson?['changed'] == true;
                                  final subject = lesson?['subject'] as String?;
                                  final teacher =
                                      lesson == null ||
                                          (!preview && !widget.teachers)
                                      ? ''
                                      : preview
                                      ? (lesson['teacher'] as String?) ?? ''
                                      : displayTeacher(lesson);
                                  final cell = Container(
                                    alignment: Alignment.center,
                                    constraints: const BoxConstraints(
                                      minHeight: 50,
                                    ),
                                    color: changed ? tint : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          subject ?? '—',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: subject == null
                                                ? CupertinoColors.tertiaryLabel
                                                      .resolveFrom(context)
                                                : textColor,
                                          ),
                                        ),
                                        if (teacher.isNotEmpty)
                                          Text(
                                            teacher,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w300,
                                              color: CupertinoColors
                                                  .secondaryLabel
                                                  .resolveFrom(context),
                                            ),
                                          ),
                                        if (changed)
                                          Text(
                                            '대체',
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                  final VoidCallback? inspect =
                                      changed && !preview
                                      ? () => showLessonChange(
                                          dates[day],
                                          period,
                                          lesson,
                                        )
                                      : null;
                                  return Semantics(
                                    label:
                                        '${names[dates[day].weekday - 1]}요일 $period교시 ${subject ?? '빈 교시'}${changed ? ' 대체' : ''}${teacher.isEmpty ? '' : ' $teacher 선생님'}',
                                    excludeSemantics: true,
                                    button: inspect != null,
                                    hint: changed ? '변경 전후 수업 보기' : null,
                                    onTap: inspect,
                                    child: inspect != null
                                        ? GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            excludeFromSemantics: true,
                                            onTap: inspect,
                                            child: cell,
                                          )
                                        : cell,
                                  );
                                },
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: SelectionLoading(),
                )
              else if (slots.isEmpty && maxRows != 0)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('등록된 수업 없음'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
