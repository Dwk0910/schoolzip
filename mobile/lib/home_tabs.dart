import 'package:material_ui/material_ui.dart' show Icons;

import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

class HomeTabsLayout extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Widget child;
  const HomeTabsLayout({
    super.key,
    required this.index,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 70 + MediaQuery.paddingOf(context).bottom,
            child: _NativeTabs(index: index, onChanged: onChanged),
          ),
        ],
      );
    }
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = CupertinoColors.systemIndigo.resolveFrom(context);
    final surface = dark ? const Color(0xff24242b) : CupertinoColors.white;
    final radius = BorderRadius.circular(36);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              width: 308,
              height: 66,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(
                      alpha: dark ? .3 : .12,
                    ),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          surface.withValues(alpha: .93),
                          surface.withValues(alpha: .68),
                        ],
                      ),
                      border: Border.all(
                        color: CupertinoColors.white.withValues(
                          alpha: dark ? .24 : .87,
                        ),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedAlign(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment(index.toDouble() - 1, 0),
                          child: FractionallySizedBox(
                            widthFactor: 1 / 3,
                            heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: dark ? .23 : .10,
                                ),
                                borderRadius: radius,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (final (i, label, icon) in [
                              (0, '시간표', CupertinoIcons.calendar),
                              (1, '급식', Icons.restaurant_rounded),
                              (2, '설정', CupertinoIcons.gear),
                            ])
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: index == i,
                                  label: label,
                                  excludeSemantics: true,
                                  onTap: () => onChanged(i),
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => onChanged(i),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 24,
                                          color: index == i
                                              ? accent
                                              : CupertinoColors.label
                                                    .resolveFrom(context),
                                        ),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: index == i
                                                ? accent
                                                : CupertinoColors.label
                                                      .resolveFrom(context),
                                          ),
                                        ),
                                      ],
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NativeTabs extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _NativeTabs({required this.index, required this.onChanged});
  @override
  State<_NativeTabs> createState() => _NativeTabsState();
}

class _NativeTabsState extends State<_NativeTabs> {
  MethodChannel? channel;
  @override
  void didUpdateWidget(_NativeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      channel?.invokeMethod<void>('select', widget.index);
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'schoolzip/tabs',
    onPlatformViewCreated: (id) {
      if (!mounted) return;
      final bridge = MethodChannel('schoolzip/tabs/$id');
      channel = bridge;
      bridge.setMethodCallHandler((call) async {
        if (mounted && call.method == 'tap') {
          widget.onChanged(call.arguments as int);
        }
      });
      bridge.invokeMethod<void>('select', widget.index);
    },
  );
}

/// Keep each tab alive without adding a custom page transition over the
/// native iOS tab bar's selection animation.
class TabBody extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const TabBody({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (var i = 0; i < children.length; i++)
        Offstage(
          offstage: i != index,
          child: TickerMode(enabled: i == index, child: children[i]),
        ),
    ],
  );
}
