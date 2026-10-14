import '../api/types.dart';
import '../i18n/i18n.dart';

const _days = {
  'en': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
  'hi': ['रवि', 'सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि'],
  'kn': ['ಭಾನು', 'ಸೋಮ', 'ಮಂಗಳ', 'ಬುಧ', 'ಗುರು', 'ಶುಕ್ರ', 'ಶನಿ'],
};
const _months = {
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'hi': ['जन', 'फ़र', 'मार्च', 'अप्रैल', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्टू', 'नव', 'दिस'],
  'kn': ['ಜನ', 'ಫೆಬ್ರ', 'ಮಾರ್ಚ್', 'ಏಪ್ರಿ', 'ಮೇ', 'ಜೂನ್', 'ಜುಲೈ', 'ಆಗ', 'ಸೆಪ್ಟೆಂ', 'ಅಕ್ಟೋ', 'ನವೆಂ', 'ಡಿಸೆಂ'],
};

// Dart's weekday is 1 (Mon)…7 (Sun); JS getDay() is 0 (Sun)…6 (Sat).
String _day(DateTime d) => _days[getLang()]![d.weekday % 7];
String _month(DateTime d) => _months[getLang()]![d.month - 1];

/// Server timestamps are ISO strings; everything is shown in the phone's local time.
DateTime parseIso(String iso) => DateTime.parse(iso).toLocal();

String clock(DateTime d) {
  final h = d.hour;
  final m = d.minute;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $suffix';
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today · 5:00 PM", "Sat, 21 Sep · 7:00 AM", or "20–23 Sep" for multi-day plans.
String planDate(String? startIso, [String? endIso]) {
  if (startIso == null || startIso.isEmpty) return tr('Date not set');
  final start = parseIso(startIso);
  if (endIso != null && endIso.isNotEmpty) {
    final end = parseIso(endIso);
    if (!_sameDay(start, end)) {
      if (start.month == end.month) return '${start.day}–${end.day} ${_month(end)}';
      return '${start.day} ${_month(start)} – ${end.day} ${_month(end)}';
    }
  }
  final now = DateTime.now();
  if (_sameDay(start, now)) return '${tr('Today')} · ${clock(start)}';
  if (_sameDay(start, now.add(const Duration(days: 1)))) return '${tr('Tomorrow')} · ${clock(start)}';
  return '${_day(start)}, ${start.day} ${_month(start)} · ${clock(start)}';
}

String shortDate(String iso) {
  final d = parseIso(iso);
  return '${d.day} ${_month(d)}';
}

/// Notification / report timestamps: "Just now", "8 min ago", "3 hr ago", "6:40 PM", "Mon", "14 Sep".
String relativeTime(String iso) {
  final d = parseIso(iso);
  final diff = DateTime.now().difference(d).inMilliseconds / 1000;
  if (diff < 60) return tr('Just now');
  if (diff < 3600) return tr('{n} min ago', {'n': (diff / 60).floor()});
  if (diff < 6 * 3600) return tr('{n} hr ago', {'n': (diff / 3600).floor()});
  if (diff < 2 * 86400) return clock(d);
  if (diff < 7 * 86400) return _day(d);
  return shortDate(iso);
}

/// 'Today' | 'Yesterday' | 'This week' | 'Earlier'
String sectionFor(String iso) {
  final d = parseIso(iso);
  final now = DateTime.now();
  if (_sameDay(d, now)) return 'Today';
  if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (now.difference(d).inMilliseconds < 7 * 86400000) return 'This week';
  return 'Earlier';
}

String dayLabel(String iso) {
  final d = parseIso(iso);
  final now = DateTime.now();
  if (_sameDay(d, now)) return tr('Today');
  if (_sameDay(d, now.subtract(const Duration(days: 1)))) return tr('Yesterday');
  return '${_day(d)}, ${d.day} ${_month(d)}';
}

String monthYear(String iso) {
  final d = parseIso(iso);
  return '${_month(d)} ${d.year}';
}

String messageTime(String iso) => clock(parseIso(iso));

const _enMonthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _enMonthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Sep 2024" — toLocaleDateString('en-IN', { month: 'short', year: 'numeric' }).
String enMonthYear(String iso) {
  final d = parseIso(iso);
  return '${_enMonthsShort[d.month - 1]} ${d.year}';
}

/// "14 September 2024" — toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' }).
String enLongDate(String iso) {
  final d = parseIso(iso);
  return '${d.day} ${_enMonthsLong[d.month - 1]} ${d.year}';
}

/// "14 Sept 2024, 6:40 pm" — toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }).
String enMediumDateTime(String iso) {
  final d = parseIso(iso);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${_enMonthsShort[d.month - 1]} ${d.year}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'pm' : 'am'}';
}

final _initialsStrip = RegExp(r"[’'.,]");
final _spaces = RegExp(r'\s+');

String initials(String name) {
  final parts = name.replaceAll(_initialsStrip, '').split(_spaces).where((p) => p.isNotEmpty);
  final s = parts.map((p) => String.fromCharCode(p.runes.first)).join();
  final two = s.runes.take(2).map(String.fromCharCode).join().toUpperCase();
  return two.isEmpty ? '?' : two;
}

String firstName(String name) => name.split(_spaces).first;

const _tones = ['mint', 'violet', 'coral', 'blue'];
String toneNameFor(int id) => _tones[id.abs() % _tones.length];

String intentLabel(String i) {
  final match = intents.where((x) => x.value == i);
  return tr(match.isEmpty ? i : match.first.label);
}

/// "OPEN TO ACTIVITY PARTNERS" kicker shown above names.
String intentKicker(List<String> list) {
  if (list.isEmpty) return '';
  return tr('Open to {intents}', {'intents': list.take(2).map(intentLabel).join(' · ')}).toUpperCase();
}

const _signalLabels = {
  'IDENTITY': 'Identity verified',
  'ORGANIZER': 'Organizer verified',
  'OFFICIAL': 'Official event',
  'PHONE': 'Phone verified',
  'EMAIL': 'Email verified',
};

String signalLabel(Signal s) => tr(_signalLabels[s] ?? s);

List<Signal> sortSignals(List<Signal> s) {
  int rank(Signal x) {
    final i = signalOrder.indexOf(x);
    return i < 0 ? 99 : i;
  }

  return [...s]..sort((a, b) => rank(a) - rank(b));
}

/// The single strongest signal, for compact rows ("Phone verified").
String? topSignal(List<Signal> s) => s.isEmpty ? null : signalLabel(sortSignals(s).first);
