import 'package:cupertino_ui/cupertino_ui.dart';

import 'controls.dart';

class GridColumn {
  final String label, detail;
  final bool today, highlighted;
  final String? badge;
  const GridColumn(
    this.label,
    this.detail, {
    this.today = false,
    this.badge,
    this.highlighted = false,
  });
}

class GridLesson {
  final String subject, secondary, semantics;
  final bool changed;
  final VoidCallback? onTap;
  const GridLesson({
    required this.subject,
    this.secondary = '',
    this.semantics = '',
    this.changed = false,
    this.onTap,
  });
}

class TimetableGrid extends StatelessWidget {
  final List<GridColumn> columns;
  final Map<(int, int), List<GridLesson>> cells;
  final int periods;
  final bool loading, showEmpty;
  const TimetableGrid({
    super.key,
    required this.columns,
    required this.cells,
    required this.periods,
    this.loading = false,
    this.showEmpty = true,
  });
  @override
  Widget build(BuildContext context) {
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    final tint = accent.withValues(alpha: .12);
    Widget lesson(GridLesson? entry) {
      final body = Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        color: entry?.changed == true ? tint : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry?.subject ?? '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    (entry == null
                            ? CupertinoColors.tertiaryLabel
                            : CupertinoColors.label)
                        .resolveFrom(context),
              ),
            ),
            if (entry?.secondary.isNotEmpty == true)
              Text(
                entry!.secondary,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            if (entry?.changed == true)
              Text(
                '대체',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
          ],
        ),
      );
      return Semantics(
        label: entry?.semantics,
        excludeSemantics: entry?.semantics.isNotEmpty == true,
        button: entry?.onTap != null,
        onTap: entry?.onTap,
        hint: entry?.changed == true ? '변경 전후 수업 보기' : null,
        child: entry?.onTap == null
            ? body
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: entry!.onTap,
                child: body,
              ),
      );
    }

    if (!loading && showEmpty && cells.isEmpty) {
      return const TimetableEmptyResult();
    }
    return Column(
      children: [
        SizedBox(
          key: const ValueKey('today-badge-space'),
          height: MediaQuery.textScalerOf(context).scale(11) * 1.4 + 9,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                const SizedBox(width: 34),
                for (final column in columns)
                  Expanded(
                    child: Center(
                      child: column.today || column.badge != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                column.badge ?? '오늘',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Table(
                columnWidths: const {0: FixedColumnWidth(34)},
                defaultVerticalAlignment:
                    TableCellVerticalAlignment.intrinsicHeight,
                border: TableBorder.symmetric(
                  inside: BorderSide(
                    width: .5,
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
                      for (final column in columns)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Column(
                            children: [
                              Text(
                                column.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                              Text(
                                column.detail,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  for (var period = 1; period <= periods; period++)
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
                        for (var column = 0; column < columns.length; column++)
                          ColoredBox(
                            color: columns[column].highlighted
                                ? accent.withValues(alpha: .09)
                                : const Color(0x00000000),
                            child: Center(
                              child: cells[(column, period)]?.isNotEmpty == true
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final entry
                                            in cells[(column, period)]!)
                                          lesson(entry),
                                      ],
                                    )
                                  : Semantics(
                                      label:
                                          '${columns[column].label}요일 $period교시 빈 교시',
                                      excludeSemantics: true,
                                      child: lesson(null),
                                    ),
                            ),
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
              else if (cells.isEmpty && showEmpty)
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

class TimetableEmptyResult extends StatelessWidget {
  const TimetableEmptyResult({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      children: [
        Icon(
          CupertinoIcons.calendar,
          size: 54,
          color: CupertinoColors.systemIndigo.resolveFrom(context),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            '등록된 수업이 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '다른 날짜나 선택 항목의 시간표를 확인해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );
}
