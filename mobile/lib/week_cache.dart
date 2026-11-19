/// Short-lived decoded responses for switching between school weeks.
class WeekCache {
  final Future<dynamic> Function(Uri) fetch;
  final DateTime Function() now;
  final _ready = <Uri, ({DateTime until, dynamic table})>{};
  final _pending = <(Uri, DateTime), Future<dynamic>>{};

  WeekCache(this.fetch, {this.now = DateTime.now});

  Future<dynamic> get(Uri uri) {
    final time = now().toUtc();
    final korea = time.add(const Duration(hours: 9));
    final nextMonday = DateTime.utc(
      korea.year,
      korea.month,
      korea.day + 8 - korea.weekday,
    ).subtract(const Duration(hours: 9));
    final entry = _ready[uri];
    if (entry != null && time.isBefore(entry.until)) {
      return Future.value(entry.table);
    }
    final key = (uri, nextMonday);
    return _pending.putIfAbsent(key, () async {
      try {
        final table = await Future.sync(() => fetch(uri));
        final until = time.add(const Duration(seconds: 30));
        final expires = until.isBefore(nextMonday) ? until : nextMonday;
        if (now().toUtc().isBefore(expires)) {
          _ready.remove(uri);
          if (_ready.length >= 4) _ready.remove(_ready.keys.first);
          _ready[uri] = (until: expires, table: table);
        }
        return table;
      } finally {
        _pending.remove(key);
      }
    });
  }
}
