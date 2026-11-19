import 'package:cupertino_ui/cupertino_ui.dart';

import 'controls.dart';

import 'package:flutter/services.dart';

Future<T?> showSchoolSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool draggable = false,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '닫기',
    barrierColor: const Color(0x66000000),
    transitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 310),
    pageBuilder: (ctx, _, _) {
      final sheet = builder(ctx);
      return Align(
        alignment: Alignment.bottomCenter,
        child: draggable
            ? Dismissible(
                key: const ValueKey('draggable-sheet'),
                direction: DismissDirection.down,
                dismissThresholds: const {DismissDirection.down: .25},
                resizeDuration: null,
                onDismissed: (_) => Navigator.pop(ctx),
                child: sheet,
              )
            : sheet,
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final closing = animation.status == AnimationStatus.reverse;
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(
              CurveTween(
                curve: closing ? Curves.easeOutQuad : Curves.easeOutCubic,
              ),
            )
            .animate(animation),
        child: child,
      );
    },
  );
}

class ResetSheet extends StatefulWidget {
  const ResetSheet({super.key});
  @override
  State<ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<ResetSheet> {
  double progress = 0;
  bool dragging = false;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    decoration: BoxDecoration(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        primary: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4.resolveFrom(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '전체 초기화할까요?',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '저장한 학교와 반, 선생님 표시 이름, 시간표 설정과 위젯 데이터를 삭제해요. 삭제하면 되돌릴 수 없어요.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (ctx, box) {
                final travel = box.maxWidth - 52;
                final duration = dragging || MediaQuery.disableAnimationsOf(ctx)
                    ? Duration.zero
                    : const Duration(milliseconds: 220);
                final danger = CupertinoColors.systemRed.resolveFrom(ctx);
                final ink = CupertinoTheme.brightnessOf(ctx) == Brightness.dark
                    ? const Color(0xffffb4ae)
                    : const Color(0xffa41b19);
                return Container(
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(sheetActionRadius),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 48 + progress * travel,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: danger.withValues(alpha: .21),
                            borderRadius: BorderRadius.circular(
                              sheetActionRadius,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(ctx)
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                          child: Text(
                            progress >= .98 ? '놓아서 삭제' : '밀어서 삭제',
                            key: ValueKey(progress >= .98),
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        left: 4 + progress * travel,
                        top: 4,
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        child: Semantics(
                          label: '삭제하려면 오른쪽 끝까지 미세요',
                          child: GestureDetector(
                            key: const ValueKey('delete-thumb'),
                            onHorizontalDragStart: (_) =>
                                setState(() => dragging = true),
                            onHorizontalDragUpdate: (d) {
                              final next = (progress + d.delta.dx / travel)
                                  .clamp(0.0, 1.0);
                              if (progress < .98 && next >= .98) {
                                HapticFeedback.selectionClick();
                              }
                              setState(() => progress = next);
                            },
                            onHorizontalDragCancel: () => setState(() {
                              dragging = false;
                              progress = 0;
                            }),
                            onHorizontalDragEnd: (_) {
                              if (progress >= .98) {
                                Navigator.pop(ctx, true);
                              } else {
                                setState(() {
                                  dragging = false;
                                  progress = 0;
                                });
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: danger,
                                borderRadius: BorderRadius.circular(
                                  sheetActionRadius - 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.black.withValues(
                                      alpha: .13,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: MediaQuery.disableAnimationsOf(ctx)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 160),
                                child: Icon(
                                  progress >= .98
                                      ? CupertinoIcons.trash_fill
                                      : CupertinoIcons.lock_open,
                                  key: ValueKey(progress >= .98),
                                  size: 21,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const SheetCancelButton(),
          ],
        ),
      ),
    ),
  );
}
