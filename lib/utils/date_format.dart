const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int v) => v.toString().padLeft(2, '0');

String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// "Today", "Tomorrow", "Yesterday", or e.g. "Tue 21 Oct" (with the year
/// when it isn't the current one).
String formatDay(DateTime t, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(t.year, t.month, t.day);
  final diff = d
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final base = '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
  return t.year == today.year ? base : '$base ${t.year}';
}

String formatDateTime(DateTime t, {DateTime? now}) =>
    '${formatDay(t, now: now)}, ${formatTime(t)}';
