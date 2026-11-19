import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_names.dart';
import 'widget_link.dart';

// Retained locally across roster changes; suggestions never establish identity.
int teacherMatchScore(
  Map<String, dynamic> previous,
  Map<String, String> current,
) {
  final a = originalTeacherLabel(previous['original'] as String? ?? '');
  final b = originalTeacherLabel(current['original'] ?? '');
  var score = 0;
  if (a == b && a.replaceAll('*', '').isNotEmpty) score += 60;
  if (a.isNotEmpty && b.isNotEmpty && a[0] != '*' && a[0] == b[0]) score += 10;
  Set<String> subjects(String value) => value
      .split(' · ')
      .map((e) => e.replaceAll(RegExp(r'[0-9ⅠⅡⅢ\s]'), ''))
      .toSet();
  if (subjects(previous['subject'] as String? ?? '')
      .intersection(subjects(current['subject'] ?? ''))
      .any((s) => s.isNotEmpty)) {
    score += 25;
  }
  return score;
}

class TeacherSharing {
  final String code, school;
  final prefs = SharedPreferencesAsync();
  TeacherSharing(this.code, this.school);
  Future<Map<String, dynamic>> history() async =>
      jsonDecode(await prefs.getString('teacherHistory.$code') ?? '{}')
          as Map<String, dynamic>;
  Future<void> remember(List<Map<String, String>> roster) async {
    final stored = await history();
    for (final entry in roster) {
      stored[entry['key']!] = entry;
    }
    await prefs.setString('teacherHistory.$code', jsonEncode(stored));
  }

  Future<List<Map<String, String>>> previous(
    List<Map<String, String>> roster,
    TeacherNames names,
  ) async {
    final stored = await history();
    final active = roster.map((e) => e['key']).toSet();
    final linked =
        jsonDecode(await prefs.getString('teacherLinks.$code') ?? '{}') as Map;
    final result = <Map<String, String>>[];
    for (final saved in names.entries) {
      if (!saved.key.startsWith('@id:') ||
          active.contains(saved.key) ||
          active.contains(linked[saved.key])) {
        continue;
      }
      for (final alias in saved.value.entries) {
        final old = Map<String, dynamic>.from(
          stored[saved.key] as Map? ?? {'original': alias.key, 'subject': ''},
        );
        final candidates =
            roster
                .where((e) => names[e['key']]?[e['original']] == null)
                .toList()
              ..sort(
                (a, b) => teacherMatchScore(
                  old,
                  b,
                ).compareTo(teacherMatchScore(old, a)),
              );
        for (final candidate in candidates) {
          final score = teacherMatchScore(old, candidate);
          result.add({
            'key': candidate['key']!,
            'original': candidate['original']!,
            'value': alias.value,
            'source': saved.key,
            'title':
                '${alias.value} 선생님 → ${originalTeacherLabel(candidate['original']!)} 선생님',
            'detail':
                '${old['subject'] ?? ''} → ${candidate['subject']} · ${score >= 60
                    ? '이름 일치 후보'
                    : score > 0
                    ? '과목·이름 참고 후보'
                    : '직접 확인 필요'}',
          });
        }
      }
    }
    return result;
  }

  Future<dynamic> request(
    String method, [
    List<Map<String, String>>? entries,
  ]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$timetableBaseUrl/api/teacher-names/$code')
          .replace(queryParameters: {'name': school});
      final req = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 10));
      if (entries != null) {
        var token = await prefs.getString('teacherContributor');
        if (token == null) {
          final random = Random.secure();
          token = List.generate(
            32,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
          await prefs.setString('teacherContributor', token);
        }
        req.headers.set('X-Schoolzip-Installation', token);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'entries': entries}));
      }
      final response = await req.close().timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw const HttpException('선생님 이름 서버에 연결하지 못했어요.');
      }
      return jsonDecode(
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 10)),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> publish(
    List<Map<String, String>> roster,
    TeacherNames names,
  ) async {
    final imported = jsonDecode(
      await prefs.getString('teacherImported.$code') ?? '{}',
    ) as Map;
    final entries = <Map<String, String>>[];
    for (final teacher in roster) {
      final value = names[teacher['key']]?[teacher['original']];
      if (value != null &&
          teacher['teacherId'] != null &&
          imported[teacher['key']] != value) {
        entries.add({
          'teacherId': teacher['teacherId']!,
          'original': teacher['original']!,
          'value': value,
        });
      }
    }
    // A failed upload remains pending: retry after the next edit or timetable load.
    await request('PUT', entries);
  }

  Future<List<Map<String, String>>> shared(
    List<Map<String, String>> roster,
    TeacherNames names,
  ) async {
    final data = await request('GET') as List;
    final current = {for (final e in roster) e['teacherId']: e};
    return [
      for (final row in data)
        if (current[row['teacherId']] != null &&
            names[current[row['teacherId']]!['key']]?[row['original']] == null)
          {
            'key': current[row['teacherId']]!['key']!,
            'original': row['original'] as String,
            'value': row['value'] as String,
            'source': 'shared:${row['teacherId']}',
            'title':
                '${originalTeacherLabel(row['original'] as String)} → ${row['value']} 선생님',
            'detail':
                '${current[row['teacherId']]!['subject']} · ${row['submissions']}개 기기의 입력 · 미검증',
          },
    ];
  }

  Future<TeacherNames> apply(
    List<Map<String, String>> choices,
    SchoolTeacherNames store, {
    required bool shared,
  }) async {
    var names = await store.read();
    final imported = jsonDecode(
      await prefs.getString('teacherImported.$code') ?? '{}',
    ) as Map;
    final links =
        jsonDecode(await prefs.getString('teacherLinks.$code') ?? '{}') as Map;
    for (final choice in choices) {
      final key = choice['key']!, original = choice['original']!;
      if (names[key]?[original] != null) continue;
      names = await store.save(key, original, choice['value']!);
      if (shared) {
        imported[key] = choice['value'];
      } else {
        links[choice['source']] = key;
        if (imported[choice['source']] == choice['value']) {
          imported[key] = choice['value'];
        }
      }
    }
    await prefs.setString('teacherImported.$code', jsonEncode(imported));
    await prefs.setString('teacherLinks.$code', jsonEncode(links));
    return names;
  }
}
