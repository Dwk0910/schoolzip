import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

const sheetActionRadius = 16.0;

class SheetCancelButton extends StatelessWidget {
  const SheetCancelButton({super.key});
  @override
  Widget build(BuildContext context) => PressButton(
    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
    padding: const EdgeInsets.symmetric(vertical: 15),
    onPressed: () => Navigator.pop(context),
    child: Text(
      '취소',
      style: TextStyle(
        color: CupertinoColors.label.resolveFrom(context),
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class PressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  const PressButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding,
    this.color,
  });
  @override
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  bool down = false;
  void pressed(bool next) {
    if (next != down) {
      setState(() => down = next);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.onPressed == null ? null : (_) => pressed(true),
    onPointerCancel: (_) => pressed(false),
    onPointerUp: (_) => pressed(false),
    child: AnimatedScale(
      scale: down ? 0.97 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: down ? 90 : 180),
      curve: Curves.easeOutCubic,
      child: CupertinoButton(
        onPressed: widget.onPressed,
        padding: widget.padding,
        color: widget.color,
        disabledColor: widget.color ?? CupertinoColors.quaternarySystemFill,
        borderRadius: BorderRadius.circular(sheetActionRadius),
        child: widget.child,
      ),
    ),
  );
}

class WeekControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool native;
  const WeekControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.native = true,
  });
  @override
  Widget build(BuildContext context) {
    if (native && Platform.isIOS) {
      return _NativeWeekControl(value: value, onChanged: onChanged);
    }
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    final radius = BorderRadius.circular(28);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      ),
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onHorizontalDragEnd: (event) =>
              onChanged(event.localPosition.dx < box.maxWidth / 2 ? 0 : 1),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: value == 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground
                            .resolveFrom(context),
                        borderRadius: radius,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x170D1930),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final index in [0, 1])
                    Expanded(
                      child: Semantics(
                        selected: value == index,
                        child: PressButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: () => onChanged(index),
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: value == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color:
                                  (value == index
                                          ? CupertinoColors.label
                                          : CupertinoColors.secondaryLabel)
                                      .resolveFrom(context),
                            ),
                            child: Text(index == 0 ? '이번 주' : '다음 주'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupProgress extends StatelessWidget {
  static const duration = Duration(milliseconds: 380);
  final int step;
  final bool complete;
  const SetupProgress({super.key, required this.step, required this.complete});
  @override
  Widget build(BuildContext context) {
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);
    final track = CupertinoColors.systemGrey4.resolveFrom(context);
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    return Semantics(
      label: complete
          ? '학교·학급 설정 완료'
          : step == 1
          ? '2단계 중 2단계, 학교 선택 완료, 학급 선택'
          : '2단계 중 1단계, 학교 선택',
      excludeSemantics: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            SizedBox(
              height: 24,
              child: LayoutBuilder(
                builder: (_, box) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: box.maxWidth / 4,
                      right: box.maxWidth / 4,
                      child: Container(
                        key: const ValueKey('setup-connecting-line'),
                        height: 3,
                        color: track,
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: step > 0 || complete ? 1 : 0,
                          ),
                          duration: motion,
                          curve: Curves.easeInOutCubic,
                          builder: (_, value, _) => FractionallySizedBox(
                            widthFactor: value,
                            child: ColoredBox(
                              color: accent,
                              child: const SizedBox(height: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < 2; index++)
                          Expanded(
                            child: Center(
                              child: AnimatedContainer(
                                key: ValueKey('setup-step-$index'),
                                duration: motion,
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index <= step || complete
                                      ? accent
                                      : track,
                                ),
                                alignment: Alignment.center,
                                child: complete || index < step
                                    ? const Icon(
                                        CupertinoIcons.check_mark,
                                        size: 14,
                                        color: CupertinoColors.white,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: index == step
                                              ? CupertinoColors.white
                                              : muted,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var index = 0; index < 2; index++)
                  Expanded(
                    child: Text(
                      index == 0 ? '학교 선택' : '학급 선택',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: index == step
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: index <= step || complete
                            ? CupertinoColors.label.resolveFrom(context)
                            : muted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ClassPicker extends StatefulWidget {
  final Map<String, List<String>> rooms;
  final String grade, room;
  final String? schoolName, saveError;
  final void Function(String, String)? onConfirm;
  final bool saving;
  const ClassPicker({
    this.schoolName,
    this.onConfirm,
    this.saveError,
    this.saving = false,
    super.key,
    required this.rooms,
    required this.grade,
    required this.room,
  });
  @override
  State<ClassPicker> createState() => _ClassPickerState();
}

class _ClassPickerState extends State<ClassPicker> {
  late String grade = widget.grade, room = widget.room;
  @override
  Widget build(BuildContext context) {
    final inline = widget.onConfirm != null;
    final columns = Row(
      children: [
        options(
          '학년',
          widget.rooms.keys.toList(),
          grade,
          (g) => setState(() {
            grade = g;
            if (!widget.rooms[g]!.contains(room)) room = widget.rooms[g]!.first;
          }),
        ),
        const SizedBox(width: 12),
        options(
          '반',
          widget.rooms[grade]!,
          room,
          (r) => setState(() => room = r),
        ),
      ],
    );
    final confirm = PressButton(
      padding: inline ? null : const EdgeInsets.symmetric(vertical: 15),
      color: CupertinoColors.systemIndigo,
      onPressed: () {
        if (inline) {
          widget.onConfirm!(grade, room);
        } else {
          Navigator.pop(context, (grade, room));
        }
      },
      child: widget.saving
          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
          : Text(
              inline ? '$grade학년 $room반으로 시작하기' : '$grade학년 $room반 적용',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
    if (inline) {
      return AbsorbPointer(
        absorbing: widget.saving,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClassHeading(school: widget.schoolName!),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: columns,
                ),
              ),
              if (widget.saveError != null)
                Text(
                  widget.saveError!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              const SizedBox(height: 14),
              confirm,
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '학년·반 선택',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .34,
                ),
                child: columns,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: SheetCancelButton()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: confirm),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget options(
    String unit,
    List<String> values,
    String selected,
    ValueChanged<String> select,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 4),
            child: Text(
              unit,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey(unit == '반' ? grade : unit),
              children: [
                for (final n in values)
                  Semantics(
                    selected: n == selected,
                    child: PressButton(
                      color: n == selected
                          ? CupertinoColors.tertiarySystemFill.resolveFrom(
                              context,
                            )
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      onPressed: () => select(n),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$n$unit',
                            style: TextStyle(
                              color: CupertinoColors.label.resolveFrom(context),
                              fontWeight: n == selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (n == selected)
                            Icon(
                              CupertinoIcons.check_mark,
                              size: 17,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                        ],
                      ),
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

const selectionHeaderConstraints = BoxConstraints(minHeight: 56);

class SelectionLoading extends StatelessWidget {
  const SelectionLoading({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Semantics(
      label: '불러오는 중',
      child: const CupertinoActivityIndicator(),
    ),
  );
}

class ClassHeading extends StatelessWidget {
  final String school;
  const ClassHeading({super.key, required this.school});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: selectionHeaderConstraints,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          school,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          '학년과 반을 선택해 주세요',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
      ],
    ),
  );
}

class LessonChangeRows extends StatelessWidget {
  final Map<String, dynamic>? original;
  final Map<String, dynamic> lesson;
  final String Function(Map<String, dynamic>)? teacherLabel;
  final ValueChanged<Map<String, dynamic>>? onEdit;
  const LessonChangeRows({
    this.teacherLabel,
    this.onEdit,
    super.key,
    required this.original,
    required this.lesson,
  });
  @override
  Widget build(BuildContext ctx) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(ctx);
    Widget detail(String label, Map<String, dynamic>? value) {
      final subject = (value?['subject'] as String?)?.trim() ?? '';
      final teacher = value == null
          ? ''
          : teacherLabel?.call(value) ??
                (value['teacher'] as String?)?.trim() ??
                '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label, style: TextStyle(color: secondary, fontSize: 14)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.isNotEmpty ? subject : '정보 없음',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: value == null
                          ? secondary
                          : CupertinoColors.label.resolveFrom(ctx),
                    ),
                  ),
                  if (teacher.isNotEmpty)
                    Text(
                      '$teacher 선생님',
                      style: TextStyle(color: secondary, fontSize: 14),
                    ),
                ],
              ),
            ),
            if (onEdit != null &&
                value != null &&
                teacher.isNotEmpty &&
                subject.isNotEmpty)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => onEdit!(value),
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 19,
                  semanticLabel: '$label 선생님 표시 이름 편집',
                ),
              ),
          ],
        ),
      );
    }

    return Column(children: [detail('변경 전', original), detail('변경 후', lesson)]);
  }
}

class _NativeWeekControl extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _NativeWeekControl({required this.value, required this.onChanged});
  @override
  State<_NativeWeekControl> createState() => _NativeWeekControlState();
}

class _NativeWeekControlState extends State<_NativeWeekControl> {
  MethodChannel? channel;
  @override
  void didUpdateWidget(_NativeWeekControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      channel?.invokeMethod<void>('select', widget.value);
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: UiKitView(
      viewType: 'schoolzip/week',
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      creationParams: widget.value,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        if (!mounted) return;
        final bridge = MethodChannel('schoolzip/week/$id');
        channel = bridge;
        bridge.setMethodCallHandler((call) async {
          if (mounted && call.method == 'change') {
            widget.onChanged(call.arguments as int);
          }
        });
        bridge.invokeMethod<void>('select', widget.value);
      },
    ),
  );
}

class LargeTitleScroll extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  final List<Widget> children;
  const LargeTitleScroll({
    super.key,
    required this.title,
    this.trailing,
    required this.padding,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      CupertinoSliverNavigationBar(
        largeTitle: Text(title),
        trailing: trailing,
        automaticallyImplyLeading: false,
        transitionBetweenRoutes: false,
        padding: EdgeInsetsDirectional.only(
          start: padding.left,
          end: padding.right,
        ),
      ),
      SliverSafeArea(
        top: false,
        bottom: false,
        sliver: SliverPadding(
          padding: padding,
          sliver: SliverList.list(children: children),
        ),
      ),
    ],
  );
}
