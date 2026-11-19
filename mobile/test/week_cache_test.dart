import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolzip/week_cache.dart';

void main() {
  test('같은 주차 요청을 합치고 성공한 응답만 30초간 재사용한다', () async {
    var clock = DateTime.utc(2026, 11, 19);
    final requests = <Uri>[];
    var reply = Completer<dynamic>();
    final cache = WeekCache((uri) {
      requests.add(uri);
      return reply.future;
    }, now: () => clock);
    final current = Uri.parse('http://localhost/api/timetable?code=1&week=0');
    final next = current.replace(queryParameters: {'code': '1', 'week': '1'});
    final first = cache.get(current);
    final duplicate = cache.get(current);
    expect(requests, [current]);
    reply.complete('이번 주');
    expect(await first, '이번 주');
    expect(await duplicate, '이번 주');
    expect(await cache.get(current), '이번 주');
    reply = Completer();
    final failed = expectLater(cache.get(next), throwsStateError);
    reply.completeError(StateError('offline'));
    await failed;
    reply = Completer()..complete('다음 주');
    expect(await cache.get(next), '다음 주');
    clock = clock.add(const Duration(seconds: 31));
    reply = Completer()..complete('갱신');
    expect(await cache.get(current), '갱신');
    expect(requests, [current, next, next, current]);
  });

  test('한국 시간 월요일이 시작되면 직전 주 응답을 재사용하지 않는다', () async {
    var clock = DateTime.utc(2026, 11, 22, 14, 59, 55);
    var count = 0;
    final cache = WeekCache((_) async => ++count, now: () => clock);
    final uri = Uri.parse('http://localhost/api/timetable?code=1&week=0');
    expect(await cache.get(uri), 1);
    clock = clock.add(const Duration(seconds: 5));
    expect(await cache.get(uri), 2);
  });
}
