import 'package:intl/intl.dart';

String fmtTime(DateTime t) => DateFormat('HH:mm').format(t);

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today" / "Yesterday" / "12 Sep" — used for the date separators in chats.
String dayLabel(DateTime t, [DateTime? now]) {
  final n = now ?? DateTime.now();
  if (_sameDay(t, n)) return 'Today';
  if (_sameDay(t, n.subtract(const Duration(days: 1)))) return 'Yesterday';
  return DateFormat('d MMM').format(t);
}

/// Time shown on the right of a chat-list row: the clock time today, else the day.
String listTime(DateTime t, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return _sameDay(t, n) ? fmtTime(t) : dayLabel(t, n);
}

bool sameDay(DateTime a, DateTime b) => _sameDay(a, b);
