import 'package:cupertino_ui/cupertino_ui.dart';

import 'controls.dart';
import 'allergies.dart';
import 'empty_meal_illustration.dart';

import 'package:material_ui/material_ui.dart' show Icons;

import 'main.dart' show ErrorResult;
import 'sheets.dart';

class MealPage extends StatefulWidget {
  final Map<String, dynamic> school;
  final bool active;
  final Set<int> allergies;
  final Future<dynamic> Function(String, Map<String, String>) fetch;
  const MealPage({
    this.allergies = const {},
    super.key,
    required this.school,
    required this.active,
    required this.fetch,
  });
  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  static DateTime today() {
    final k = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(k.year, k.month, k.day);
  }

  late DateTime day = today();
  Future<dynamic>? meals;
  Future<dynamic> load() => widget.fetch('meals', {
    'name': widget.school['name'],
    'region': widget.school['region'] ?? '',
    'date': day.toIso8601String().substring(0, 10),
  })..ignore();
  @override
  void initState() {
    super.initState();
    if (widget.active) meals = load();
  }

  @override
  void didUpdateWidget(MealPage old) {
    super.didUpdateWidget(old);
    if (widget.active && meals == null) meals = load();
  }

  void select(DateTime date) => setState(() {
    day = date;
    meals = load();
  });
  Future<void> pick() async {
    final result = await showSchoolSheet<DateTime>(
      context: context,
      draggable: true,
      builder: (_) => MealDateSheet(initial: day),
    );
    if (mounted && result != null) select(result);
  }

  Widget returnToToday() => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: PressButton(
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onPressed: () => select(today()),
      child: Text(
        '오늘로 돌아가기',
        style: TextStyle(
          color: CupertinoColors.label.resolveFrom(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.active && meals == null) return const SizedBox.shrink();
    final ink = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            const Text(
              '급식 식단표',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(widget.school['name'], style: TextStyle(color: ink)),
            const SizedBox(height: 10),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(
                    context,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          select(DateTime(day.year, day.month, day.day - 1)),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: 17,
                        color: ink,
                        semanticLabel: '이전 날짜',
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: pick,
                      child: Text(
                        '${day.month}월 ${day.day}일 (${"월화수목금토일"[day.weekday - 1]})',
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          select(DateTime(day.year, day.month, day.day + 1)),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 17,
                        color: ink,
                        semanticLabel: '다음 날짜',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<dynamic>(
              future: meals,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SelectionLoading();
                }
                if (snap.hasError) {
                  return ErrorResult(
                    icon: CupertinoIcons.tray,
                    title: '급식을 불러오지 못했어요',
                    description: '잠시 후 다시 시도해 주세요.',
                    onRetry: () => select(day),
                  );
                }
                final rows = snap.data as List;
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 44,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        const ExcludeSemantics(
                          child: CustomPaint(
                            size: Size(208, 128),
                            painter: EmptyMealIllustration(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: const Text(
                            '등록된 급식이 없습니다',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '다른 날짜의 식단을 확인해 주세요.',
                          style: TextStyle(color: ink),
                        ),
                        if (day != today()) returnToToday(),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final meal in rows)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CupertinoColors
                              .secondarySystemGroupedBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.restaurant_rounded,
                                  color: CupertinoColors.systemIndigo,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    meal['type'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                Text(
                                  meal['calories'],
                                  style: TextStyle(color: ink, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final dish in meal['dishes'])
                              _DishRow(raw: dish, allergies: widget.allergies),
                          ],
                        ),
                      ),
                    if (day != today())
                      SizedBox(width: double.infinity, child: returnToToday()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  final String raw;
  final Set<int> allergies;
  const _DishRow({required this.raw, required this.allergies});
  @override
  Widget build(BuildContext context) {
    final dish = parseDish(raw);
    final matches = dish.codes.where(allergies.contains).toList();
    final other = dish.codes
        .where((c) => !allergies.contains(c))
        .map(allergenLabel)
        .join(' · ');
    final warning = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? const Color(0xffffb7ac)
        : const Color(0xffa6261c);
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: matches.isEmpty ? null : warning.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            height: MediaQuery.textScalerOf(context).scale(16) * 1.35,
            child: Center(
              child: Icon(
                matches.isEmpty
                    ? Icons.circle
                    : CupertinoIcons.exclamationmark_triangle_fill,
                size: matches.isEmpty ? 5 : 15,
                color: matches.isEmpty ? CupertinoColors.systemGrey : warning,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (matches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '내 알레르기 · ${matches.map(allergenLabel).join(" · ")}',
                      style: TextStyle(
                        color: warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (other.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      other,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MealDateSheet extends StatefulWidget {
  final DateTime initial;
  const MealDateSheet({super.key, required this.initial});
  @override
  State<MealDateSheet> createState() => _MealDateSheetState();
}

class _MealDateSheetState extends State<MealDateSheet> {
  late DateTime month = DateTime(widget.initial.year, widget.initial.month);
  void browse(int offset) =>
      setState(() => month = DateTime(month.year, month.month + offset));
  @override
  Widget build(BuildContext context) {
    final offset = month.weekday % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${month.year}년 ${month.month}월',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => browse(-1),
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            semanticLabel: '이전 달',
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => browse(1),
                          child: const Icon(
                            CupertinoIcons.chevron_right,
                            semanticLabel: '다음 달',
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        for (final label in '일월화수목금토'.split(''))
                          Expanded(
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (var week = 0; week < 6; week++)
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            for (var column = 0; column < 7; column++)
                              Expanded(
                                child: Builder(
                                  builder: (ctx) {
                                    final n = week * 7 + column - offset + 1;
                                    if (n < 1 || n > count) {
                                      return const SizedBox.shrink();
                                    }
                                    final date = DateTime(
                                      month.year,
                                      month.month,
                                      n,
                                    );
                                    final selected = date == widget.initial;
                                    return Semantics(
                                      selected: selected,
                                      child: CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () =>
                                            Navigator.pop(ctx, date),
                                        child: Container(
                                          alignment: Alignment.center,
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: selected ? accent : null,
                                          ),
                                          child: Text(
                                            '$n',
                                            style: TextStyle(
                                              color: selected
                                                  ? CupertinoColors.white
                                                  : CupertinoColors.label
                                                        .resolveFrom(ctx),
                                              fontWeight: selected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
