import 'package:cupertino_ui/cupertino_ui.dart';

Set<int> unambiguousTeacherOptions(List<Map<String, String>> options) {
  final keys = <String?, int>{}, sources = <String?, int>{};
  for (final option in options) {
    keys.update(option['key'], (v) => v + 1, ifAbsent: () => 1);
    sources.update(option['source'], (v) => v + 1, ifAbsent: () => 1);
  }
  return {
    for (var i = 0; i < options.length; i++)
      if (keys[options[i]['key']] == 1 && sources[options[i]['source']] == 1) i,
  };
}

class TeacherReviewPage extends StatefulWidget {
  final String title;
  final List<Map<String, String>> options;
  const TeacherReviewPage({
    super.key,
    required this.title,
    required this.options,
  });
  @override
  State<TeacherReviewPage> createState() => _TeacherReviewPageState();
}

class _TeacherReviewPageState extends State<TeacherReviewPage> {
  final selected = <int>{};
  String query = '';
  late final bulk = unambiguousTeacherOptions(widget.options);
  bool get bulkSelected => selected.isNotEmpty && selected.containsAll(bulk);
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text(widget.title),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: selected.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                selected.map((i) => widget.options[i]).toList(),
              ),
        child: const Text('선택 적용'),
      ),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CupertinoSearchTextField(
              placeholder: '이름 또는 과목 검색',
              onChanged: (s) => setState(() => query = s),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              '이름과 과목을 확인해 선택해 주세요. 기존 이름은 덮어쓰지 않아요. 중복 후보는 전체 선택에서 제외되니 직접 골라 주세요.',
            ),
          ),
          CupertinoButton(
            onPressed: bulk.isEmpty && selected.isEmpty
                ? null
                : () => setState(() {
                    if (bulkSelected) {
                      selected.clear();
                    } else {
                      selected.addAll(bulk);
                    }
                  }),
            child: Text(bulkSelected ? '전체 해제' : '전체 선택'),
          ),
          Expanded(
            child: widget.options.isEmpty
                ? const Center(child: Text('적용할 후보가 없어요. 기존 이름은 보관돼요.'))
                : ListView(
                    children: [
                      for (var i = 0; i < widget.options.length; i++)
                        if ('${widget.options[i]['title']} ${widget.options[i]['detail']}'
                            .toLowerCase()
                            .contains(query.toLowerCase()))
                          CupertinoListTile(
                            title: Text(
                              widget.options[i]['title']!,
                              maxLines: 3,
                            ),
                            subtitle: Text(
                              widget.options[i]['detail']!,
                              maxLines: 3,
                            ),
                            trailing: selected.contains(i)
                                ? const Icon(CupertinoIcons.check_mark)
                                : null,
                            onTap: () => setState(() {
                              if (!selected.remove(i)) {
                                selected.removeWhere(
                                  (j) =>
                                      widget.options[i]['key'] ==
                                          widget.options[j]['key'] ||
                                      widget.options[i]['source'] ==
                                          widget.options[j]['source'],
                                );
                                selected.add(i);
                              }
                            }),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
