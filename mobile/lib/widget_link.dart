import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String get timetableBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  return Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
}

Future<void> syncWidget(Map<String, dynamic>? selection) async {
  if (selection == null) return;
  final uri = Uri.parse('$timetableBaseUrl/api/timetable').replace(
    queryParameters: {
      'name': selection['name'] as String,
      'code': selection['code'].toString(),
      'week': '0',
    },
  );
  try {
    await const MethodChannel('schoolzip/today')
        .invokeMethod<void>('configure', {
          'url': uri.toString(),
          'grade': selection['grade'],
          'room': selection['room'],
        });
  } on MissingPluginException {
    // Widget tests run without a native host.
  } on PlatformException catch (error) {
    debugPrint('Widget configuration failed: ${error.code}');
  }
}

Future<void> syncTeacherNames(
  String code,
  Map<String, Map<String, String>> names,
) async {
  try {
    await const MethodChannel('schoolzip/today').invokeMethod<void>(
      'teacherNames',
      {'code': code, 'names': jsonEncode(names)},
    );
  } on MissingPluginException {
    // No native widget host in Flutter tests.
  } on PlatformException catch (error) {
    debugPrint('Widget teacher name update failed: ${error.code}');
  }
}

Future<void> publishWidgetWeek(
  Map<String, dynamic> saved,
  String start,
  List<dynamic> days,
) async {
  final monday = DateTime.parse(start);
  final schedule = <String, dynamic>{};
  for (var i = 0; i < 7; i++) {
    final date = DateTime.utc(
      monday.year,
      monday.month,
      monday.day + i,
    ).toIso8601String().substring(0, 10);
    schedule[date] = i < days.length ? days[i] : [];
  }
  try {
    await const MethodChannel('schoolzip/today')
        .invokeMethod<void>('cacheWeek', {
          'code': saved['code'].toString(),
          'grade': saved['grade'],
          'room': saved['room'],
          'days': jsonEncode(schedule),
        });
  } on PlatformException catch (e) {
    debugPrint('Widget update failed: ${e.code}');
  }
}

Future<void> resetWidget() async {
  try {
    await const MethodChannel('schoolzip/today')
        .invokeMethod<void>('reset', <String, String>{});
  } on MissingPluginException {
    return;
  }
}
