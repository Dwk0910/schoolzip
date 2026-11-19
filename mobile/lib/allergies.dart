import 'package:cupertino_ui/cupertino_ui.dart';

import 'controls.dart';

const allergenNames = [
  '',
  '난류',
  '우유',
  '메밀',
  '땅콩',
  '대두',
  '밀',
  '고등어',
  '게',
  '새우',
  '돼지고기',
  '복숭아',
  '토마토',
  '아황산류',
  '호두',
  '닭고기',
  '쇠고기',
  '오징어',
  '조개류',
  '잣',
];
final _annotation = RegExp(r'\(\s*(\d+(?:[\s.,·]+\d+)*[.\s]*)\)\s*$');
({String name, List<int> codes}) parseDish(String raw) {
  final match = _annotation.firstMatch(raw.trim());
  if (match == null) return (name: raw.trim(), codes: <int>[]);
  final codes = RegExp(r'\d+')
      .allMatches(match.group(1)!)
      .map((m) => int.parse(m[0]!))
      .toSet()
      .toList();
  return (name: raw.trim().substring(0, match.start).trim(), codes: codes);
}

String allergenLabel(int code) => code > 0 && code < allergenNames.length
    ? allergenNames[code]
    : '미확인 번호 $code';

class AllergyPicker extends StatefulWidget {
  final Set<int> selected;
  const AllergyPicker({super.key, required this.selected});
  @override
  State<AllergyPicker> createState() => _AllergyPickerState();
}

class _AllergyPickerState extends State<AllergyPicker> {
  late final values = {...widget.selected};
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('내 알레르기')),
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('급식에서 강조할 재료'),
                  children: [
                    for (var i = 1; i < allergenNames.length; i++)
                      Semantics(
                        checked: values.contains(i),
                        child: CupertinoListTile(
                          title: Text(allergenNames[i]),
                          trailing: _AllergyCheck(checked: values.contains(i)),
                          onTap: () => setState(() {
                            if (!values.remove(i)) values.add(i);
                          }),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: PressButton(
                color: CupertinoColors.systemIndigo,
                onPressed: () => Navigator.pop(context, values),
                child: const Text(
                  '저장',
                  style: TextStyle(color: CupertinoColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AllergyCheck extends StatelessWidget {
  final bool checked;
  const _AllergyCheck({required this.checked});
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    const blue = Color(0xff3182f6);
    return AnimatedContainer(
      duration: duration,
      width: 22,
      height: 22,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: checked ? blue : const Color(0x00000000),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          width: 1.6,
          color: checked
              ? blue
              : CupertinoColors.systemGrey3.resolveFrom(context),
        ),
      ),
      child: AnimatedScale(
        scale: checked ? 1 : .65,
        duration: duration,
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: checked ? 1 : 0,
          duration: duration,
          child: const Icon(
            CupertinoIcons.check_mark,
            size: 15,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}
