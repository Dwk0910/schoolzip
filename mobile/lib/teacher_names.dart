import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controls.dart';

typedef TeacherNames = Map<String, Map<String, String>>;

class SchoolTeacherNames {
  final String code;
  SchoolTeacherNames(this.code);

  Future<TeacherNames> read() async {
    final raw = await SharedPreferencesAsync().getString('teacherNames.$code');
    if (raw == null) return {};
    final stored = jsonDecode(raw) as Map<String, dynamic>;
    return stored.map(
      (key, value) => MapEntry(key, Map<String, String>.from(value)),
    );
  }

  Future<TeacherNames> save(
    String subject,
    String original,
    String input,
  ) async {
    final names = await read();
    final value = input.trim();
    if (value.isEmpty || value == original) {
      names[subject]?.remove(original);
      if (names[subject]?.isEmpty == true) names.remove(subject);
    } else {
      (names[subject] ??= {})[original] = value;
    }
    await SharedPreferencesAsync().setString(
      'teacherNames.$code',
      jsonEncode(names),
    );
    return names;
  }
}

class TeacherNameEditor extends StatefulWidget {
  final String subject, original, current;
  final Future<void> Function(String) onSave;
  const TeacherNameEditor({
    super.key,
    required this.subject,
    required this.original,
    required this.current,
    required this.onSave,
  });

  @override
  State<TeacherNameEditor> createState() => _TeacherNameEditorState();
}

class _TeacherNameEditorState extends State<TeacherNameEditor> {
  late final controller = TextEditingController(text: widget.current);
  bool saving = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save(String value) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(value);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '선생님 표시 이름',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: secondary,
                        semanticLabel: '닫기',
                      ),
                    ),
                  ],
                ),
                Text(
                  '${widget.subject} · 컴시간 표시명 ${widget.original}',
                  style: TextStyle(color: secondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: controller,
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(
                      context,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  autofocus: true,
                  readOnly: saving,
                  placeholder: '표시할 이름',
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: save,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '이 학교의 같은 과목과 표시명에 적용돼요.',
                  style: TextStyle(color: secondary, fontSize: 13),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                const SizedBox(height: 18),
                PressButton(
                  onPressed: saving ? null : () => save(controller.text),
                  color: CupertinoColors.systemIndigo.resolveFrom(context),
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.current != widget.original)
                  CupertinoButton(
                    onPressed: saving ? null : () => save(''),
                    child: const Text('컴시간 이름으로 복원'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
