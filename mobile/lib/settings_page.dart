import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  final String school, room;
  final VoidCallback onAllergies;
  final int allergyCount;
  final bool teachers, highlight;
  final void Function(String, bool) onDisplay;
  final VoidCallback onSchool, onTeachers, onReset, onGuide;
  const SettingsPage({
    required this.onAllergies,
    required this.allergyCount,
    super.key,
    required this.school,
    required this.teachers,
    required this.highlight,
    required this.onDisplay,
    required this.room,
    required this.onSchool,
    required this.onTeachers,
    required this.onReset,
    required this.onGuide,
  });
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  MethodChannel? channel;
  Map<String, String> get selection => {
    'school': widget.school,
    'room': widget.room,
    'allergyCount': widget.allergyCount.toString(),
    'showTeachers': widget.teachers.toString(),
    'highlightToday': widget.highlight.toString(),
  };
  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allergyCount != widget.allergyCount ||
        oldWidget.school != widget.school ||
        oldWidget.room != widget.room ||
        oldWidget.teachers != widget.teachers ||
        oldWidget.highlight != widget.highlight) {
      channel?.invokeMethod<void>('update', selection);
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'schoolzip/settings',
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        creationParams: selection,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          if (!mounted) return;
          final bridge = MethodChannel('schoolzip/settings/$id');
          channel = bridge;
          bridge.setMethodCallHandler((call) async {
            if (!mounted) return;
            switch (call.method) {
              case 'showTeachers':
              case 'highlightToday':
                widget.onDisplay(call.method, call.arguments as bool);
                break;
              case 'school':
                widget.onSchool();
                break;
              case 'teachers':
                widget.onTeachers();
                break;
              case 'allergies':
                widget.onAllergies();
                break;
              case 'guide':
                widget.onGuide();
                break;
              case 'reset':
                widget.onReset();
                break;
            }
          });
          bridge.invokeMethod<void>('update', selection);
        },
      );
    }
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    Widget section(String title, Widget row) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: secondary,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: row,
          ),
        ],
      ),
    );
    const rowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('설정'),
            transitionBetweenRoutes: false,
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.only(bottom: 90),
              sliver: SliverList.list(
                children: [
                  section(
                    '학교 설정',
                    CupertinoListTile(
                      padding: rowPadding,
                      title: const Text('학교 바꾸기'),
                      additionalInfo: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .43,
                        ),
                        child: Text(
                          [
                            widget.school,
                            widget.room,
                          ].where((v) => v.isNotEmpty).join(' · '),
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 14, color: secondary),
                        ),
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: widget.onSchool,
                    ),
                  ),
                  section(
                    '시간표',
                    Column(
                      children: [
                        for (final (key, label, on) in [
                          ('showTeachers', '선생님 이름 표시', widget.teachers),
                          ('highlightToday', '오늘 열 강조', widget.highlight),
                        ]) ...[
                          Semantics(
                            label: label,
                            toggled: on,
                            onTap: () => widget.onDisplay(key, !on),
                            excludeSemantics: true,
                            child: CupertinoListTile(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              title: Text(label),
                              onTap: () => widget.onDisplay(key, !on),
                              trailing: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                width: 40,
                                height: 24,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: on
                                      ? const Color(0xff3182f6)
                                      : CupertinoColors.systemGrey3.resolveFrom(
                                          context,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: AnimatedAlign(
                                  alignment: on
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  curve: Curves.easeOutCubic,
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox.square(dimension: 18),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Container(
                              height: .5,
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                        CupertinoListTile(
                          padding: rowPadding,
                          title: const Text('선생님 이름 설정'),
                          trailing: const CupertinoListTileChevron(),
                          onTap: widget.onTeachers,
                        ),
                      ],
                    ),
                  ),
                  section(
                    '급식',
                    CupertinoListTile(
                      padding: rowPadding,
                      title: const Text('내 알레르기'),
                      additionalInfo: Text(
                        widget.allergyCount == 0
                            ? '선택 안 함'
                            : '${widget.allergyCount}개 선택',
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: widget.onAllergies,
                    ),
                  ),
                  section(
                    '기타',
                    Column(
                      children: [
                        CupertinoListTile(
                          padding: rowPadding,
                          title: const Text(
                            '사용 안내 다시 보기',
                            style: TextStyle(color: CupertinoColors.systemBlue),
                          ),
                          onTap: widget.onGuide,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Container(
                            height: .5,
                            color: CupertinoColors.separator.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                        CupertinoListTile(
                          padding: rowPadding,
                          title: const Text(
                            '전체 초기화',
                            style: TextStyle(color: CupertinoColors.systemRed),
                          ),
                          onTap: widget.onReset,
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
    );
  }
}
