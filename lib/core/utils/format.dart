const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String monthShort(DateTime d) => _months[d.month - 1];

String dayShort(DateTime d) => _days[d.weekday - 1];

/// "Nov 21, 2026"
String fmtDate(DateTime d) => '${monthShort(d)} ${d.day}, ${d.year}';

/// "8:30 AM"
String fmtTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "Sat, Nov 21 · 8:30 AM"
String fmtDateTime(DateTime d) =>
    '${dayShort(d)}, ${monthShort(d)} ${d.day} · ${fmtTime(d)}';

/// "5 min ago", "3 h ago", "2 d ago"
String timeAgo(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  return fmtDate(t);
}

/// "in 3 d", "in 5 h", or "ended"
String timeLeft(DateTime t, {DateTime? now}) {
  final diff = t.difference(now ?? DateTime.now());
  if (diff.isNegative) return 'ended';
  if (diff.inHours < 1) return 'in ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'in ${diff.inHours} h';
  return 'in ${diff.inDays} d';
}

/// "₱1,234"
String peso(num value) {
  final digits = value.round().abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}₱$out';
}

String km(double value) =>
    '${value < 10 ? value.toStringAsFixed(1) : value.round()} km';

String minutes(double value) {
  final m = value.round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} min';
}

String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';
