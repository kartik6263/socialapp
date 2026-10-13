import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'hi.dart';
import 'kn.dart';

/// Languages: English is the default and the source of every key; Hindi is fully supported;
/// Kannada is the secondary language — anything not yet translated falls back to English.
typedef Lang = String; // 'en' | 'hi' | 'kn'

class LanguageOption {
  final Lang value;
  final String label;
  final String english;
  final bool secondary;
  const LanguageOption(this.value, this.label, this.english, {this.secondary = false});
}

const languages = [
  LanguageOption('en', 'English', 'English'),
  LanguageOption('hi', 'हिन्दी', 'Hindi'),
  LanguageOption('kn', 'ಕನ್ನಡ', 'Kannada', secondary: true),
];

const Map<Lang, Map<String, String>> _dicts = {'en': {}, 'hi': hi, 'kn': kn};
const _key = 'plans.lang';

// Module-level copy so non-widget helpers (date formatting) follow the current language.
Lang _current = 'en';
Lang getLang() => _current;

typedef Vars = Map<String, Object?>;

final _placeholder = RegExp(r'\{(\w+)\}');

String _fill(String template, Vars? vars) {
  if (vars == null) return template;
  return template.replaceAllMapped(_placeholder, (m) {
    final k = m.group(1)!;
    return vars.containsKey(k) ? (vars[k]?.toString() ?? '') : m.group(0)!;
  });
}

/// Translate an English source string. Missing translations fall back to English.
String tr(String key, [Vars? vars, Lang? lang]) => _fill(_dicts[lang ?? _current]?[key] ?? key, vars);

// Patterns for server-generated text with values inside ("That code is incorrect. 2 attempts remaining.").
final _patternCache = <Lang, List<({RegExp re, List<String> names, String key})>>{};

List<({RegExp re, List<String> names, String key})> _patterns(Lang lang) {
  return _patternCache.putIfAbsent(lang, () {
    return _dicts[lang]!.keys.where((k) => k.contains('{')).map((key) {
      final names = <String>[];
      final buf = StringBuffer('^');
      var last = 0;
      for (final m in _placeholder.allMatches(key)) {
        buf.write(RegExp.escape(key.substring(last, m.start)));
        names.add(m.group(1)!);
        buf.write('(.+?)');
        last = m.end;
      }
      buf.write(RegExp.escape(key.substring(last)));
      buf.write(r'$');
      return (re: RegExp(buf.toString()), names: names, key: key);
    }).toList();
  });
}

/// Translate text that arrived from the server: exact match first, then templates with placeholders.
String translateServer(String? text, [Lang? lang]) {
  final l = lang ?? _current;
  if (text == null || text.isEmpty) return '';
  if (l == 'en') return text;
  final exact = _dicts[l]![text];
  if (exact != null) return exact;
  for (final p in _patterns(l)) {
    final m = p.re.firstMatch(text);
    if (m != null) {
      return _fill(_dicts[l]![p.key]!, {for (var i = 0; i < p.names.length; i++) p.names[i]: m.group(i + 1)});
    }
  }
  return text;
}

/// Whole-sentence translation whose placeholders are styled spans (e.g. a bold phone number),
/// so word order can differ per language: trRich('Enter the code sent to {phone}.', {'phone': TextSpan(...)}).
List<InlineSpan> trRich(String key, Map<String, InlineSpan> vars) {
  final template = tr(key);
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in _placeholder.allMatches(template)) {
    if (m.start > last) out.add(TextSpan(text: template.substring(last, m.start)));
    final k = m.group(1)!;
    out.add(vars[k] ?? TextSpan(text: m.group(0)));
    last = m.end;
  }
  if (last < template.length) out.add(TextSpan(text: template.substring(last)));
  return out;
}

class I18n extends ChangeNotifier {
  /// A new instance starts in English until the saved choice loads.
  I18n() {
    _current = 'en';
  }

  static const _store = FlutterSecureStorage();
  Lang _lang = 'en';
  Lang get lang => _lang;

  Future<void> load() async {
    try {
      final v = await _store.read(key: _key);
      if (v == 'hi' || v == 'kn' || v == 'en') {
        _current = v!;
        _lang = v;
        notifyListeners();
      }
    } catch (_) {}
  }

  void setLang(Lang l) {
    if (l == _lang) return;
    _current = l;
    _lang = l;
    notifyListeners();
    _store.write(key: _key, value: l).catchError((_) {});
  }
}

/// Subscribes a widget to language changes so its tr() calls re-render.
/// Call it at the top of the build method of any screen that renders translated text.
Lang useLanguage(BuildContext context) => context.watch<I18n>().lang;
