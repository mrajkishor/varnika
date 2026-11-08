String formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0)} ${units[i]}';
}

/// Bytes/second as a network rate, e.g. "1.2 Mbps".
String formatRate(double bytesPerSecond) {
  final bits = bytesPerSecond * 8;
  if (bits < 1000) return '${bits.toStringAsFixed(0)} bps';
  if (bits < 1e6) {
    return '${(bits / 1e3).toStringAsFixed(bits < 1e4 ? 1 : 0)} Kbps';
  }
  if (bits < 1e9) {
    return '${(bits / 1e6).toStringAsFixed(bits < 1e7 ? 1 : 0)} Mbps';
  }
  return '${(bits / 1e9).toStringAsFixed(1)} Gbps';
}

String two(int n) => n.toString().padLeft(2, '0');

/// "01:02:03" style clock for a running session.
String formatClock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// Short human duration such as "2h 15m" or "45s".
String formatDurationShort(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  final h = d.inHours, m = d.inMinutes % 60;
  if (h < 24) return m == 0 ? '${h}h' : '${h}h ${m}m';
  return '${d.inDays}d ${h % 24}h';
}

String formatAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 5) return 'just now';
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatDate(DateTime t) => '${t.day} ${_months[t.month - 1]}';
String formatTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
String weekdayShort(DateTime t) => _days[t.weekday - 1];
