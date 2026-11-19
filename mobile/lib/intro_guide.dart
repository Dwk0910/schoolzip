import 'package:cupertino_ui/cupertino_ui.dart';

import 'controls.dart';
import 'timetable_views.dart';

// Only fictional display data belongs in onboarding previews.
class GuideExample {
  static const school = '스쿨집고등학교';
  static const grade = '2', room = '3';
  static final monday = DateTime.utc(2026, 3, 9);
  static const original = {'subject': '과학', 'teacher': '누리'};
  static const changed = <String, dynamic>{
    'period': 2,
    'subject': '음악',
    'teacher': '라온',
    'changed': true,
    'original': original,
  };
  static const days = <List<Map<String, dynamic>>>[
    [
      {'period': 1, 'subject': '국어', 'teacher': '다솜'},
      changed,
    ],
    [
      {'period': 1, 'subject': '미술', 'teacher': '마루'},
      {'period': 2, 'subject': '수학', 'teacher': '도담'},
    ],
    [
      {'period': 1, 'subject': '체육', 'teacher': '보람'},
      {'period': 2, 'subject': '국어', 'teacher': '다솜'},
    ],
    [
      {'period': 1, 'subject': '과학', 'teacher': '누리'},
      {'period': 2, 'subject': '미술', 'teacher': '마루'},
    ],
    [
      {'period': 1, 'subject': '수학', 'teacher': '도담'},
      {'period': 2, 'subject': '체육', 'teacher': '보람'},
    ],
  ];
}

class IntroGuide extends StatefulWidget {
  final Widget grid, weekHeader, classButton;
  final Future<void> Function() onFinish;
  final bool replay;
  const IntroGuide({
    super.key,
    required this.grid,
    required this.weekHeader,
    required this.classButton,
    required this.onFinish,
    this.replay = false,
  });

  @override
  State<IntroGuide> createState() => _IntroGuideState();
}

class _IntroGuideState extends State<IntroGuide> {
  static const slides = [
    (
      title: '우리 반 시간표가 준비됐어요',
      body: '요일과 교시가 만나는 칸에서 과목과 담당 교사를 확인하세요. 설정에서 선생님 이름을 바꿀 수 있어요.',
    ),
    (
      title: '다른 반도 살펴볼 수 있어요',
      body: '왼쪽에서 보기 모드를 고르세요. 오른쪽에서는 모드에 맞게 학년·반, 학년·날짜 또는 선생님을 선택해요.',
    ),
    (title: '다음 주가 궁금할 때', body: '시간표 위에서 ‘다음 주’를 누르세요. ‘이번 주’를 누르면 다시 돌아와요.'),
    (title: '바뀐 수업은 ‘대체’를 눌러요', body: '대체 수업 칸을 누르면 변경 전후의 과목과 선생님이 함께 보여요.'),
    (
      title: '홈 화면에서도 오늘 수업을 봐요',
      body: '홈 화면의 위젯 목록에서 스쿨집을 추가하세요. 수업 중에는 해당 교시가 강조돼요.',
    ),
  ];
  final controller = PageController();
  int page = 0;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> move(int target) async {
    if (busy || target < 0 || target >= slides.length) return;
    setState(() => busy = true);
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpToPage(target);
      } else {
        await controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 290),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onFinish();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '도움말을 저장하지 못했어요. 다시 눌러 주세요.';
        });
      }
    }
  }

  Widget preview(int index) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    switch (index) {
      case 0:
        return widget.grid;
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              GuideExample.school,
              style: TextStyle(color: secondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '주간 시간표',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: ViewDropdown(label: '요일별 보기')),
                const SizedBox(width: 8),
                Expanded(child: widget.classButton),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            // A moving onboarding preview must not embed a native platform view.
            WeekControl(native: false, value: 0, onChanged: (_) {}),
            const SizedBox(height: 10),
            widget.weekHeader,
          ],
        );
      case 3:
        return const LessonChangeRows(
          original: GuideExample.original,
          lesson: GuideExample.changed,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    GuideExample.school,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('2학년 3반', style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 5),
            Text('오늘 과목', style: TextStyle(color: secondary, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            Wrap(
              children: [
                for (final lesson in GuideExample.days.first)
                  FractionallySizedBox(
                    widthFactor: .5,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Text(
                            "${lesson['period']}교시",
                            style: TextStyle(fontSize: 12, color: secondary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lesson['subject'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((lesson['teacher'] as String?)
                                        ?.isNotEmpty ==
                                    true)
                                  Text(
                                    lesson['teacher'],
                                    style: TextStyle(
                                      color: secondary,
                                      fontSize: 11,
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
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final number = page + 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy) return;
        if (page > 0) {
          move(page - 1);
        } else {
          finish();
        }
      },
      child: Container(
        height: (MediaQuery.sizeOf(context).height * .64).clamp(0.0, 540.0),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (page > 0)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => move(page - 1),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          semanticLabel: '이전',
                        ),
                      ),
                    const Expanded(
                      child: Text(
                        '스쿨집 사용 안내',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '$number / ${slides.length}',
                      style: TextStyle(color: secondary, fontSize: 14),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: finish,
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: secondary,
                        size: 18,
                        semanticLabel: '안내 닫기',
                      ),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ColoredBox(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(
                      context,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        tween: Tween(end: number / slides.length),
                        builder: (_, value, _) => FractionallySizedBox(
                          widthFactor: value,
                          child: SizedBox(
                            height: 4,
                            child: ColoredBox(color: accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: slides.length,
                    onPageChanged: (index) => setState(() => page = index),
                    itemBuilder: (context, index) => Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ExcludeFocus(
                              child: IgnorePointer(
                                child: ExcludeSemantics(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors
                                          .systemGroupedBackground
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: preview(index),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              slides[index].title,
                              key: ValueKey('guide-title-$index'),
                              style: TextStyle(
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.7,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slides[index].body,
                              key: ValueKey('guide-body-$index'),
                              style: TextStyle(
                                color: secondary,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (page == 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '안내 속 학교와 수업은 모두 가상이에요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                PressButton(
                  color: accent,
                  onPressed: page == slides.length - 1
                      ? finish
                      : () => move(page + 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    page == slides.length - 1
                        ? (widget.replay ? '닫기' : '시작하기!')
                        : '다음',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
