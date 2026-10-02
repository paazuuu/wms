import 'package:flutter/material.dart';

/// Half-width katakana (ｺｸﾖ, ﾊﾞｲﾝﾀﾞｰ) as full-width, for display.
///
/// Suppliers still print half-width kana. A Chinese or English screen draws
/// it with a font that has no such glyphs and shows □, so it is widened —
/// the same text, only written the way every font can draw it.
String widenKana(String s) {
  if (!s.runes.any((r) => r >= 0xFF61 && r <= 0xFF9F)) return s;
  const map = '。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜';
  const dakuten = {
    'カ': 'ガ', 'キ': 'ギ', 'ク': 'グ', 'ケ': 'ゲ', 'コ': 'ゴ', 'サ': 'ザ', 'シ': 'ジ', 'ス': 'ズ', 'セ': 'ゼ', 'ソ': 'ゾ',
    'タ': 'ダ', 'チ': 'ヂ', 'ツ': 'ヅ', 'テ': 'デ', 'ト': 'ド', 'ハ': 'バ', 'ヒ': 'ビ', 'フ': 'ブ', 'ヘ': 'ベ', 'ホ': 'ボ', 'ウ': 'ヴ',
  };
  const handakuten = {'ハ': 'パ', 'ヒ': 'ピ', 'フ': 'プ', 'ヘ': 'ペ', 'ホ': 'ポ'};
  final out = StringBuffer();
  String? pending;
  void flush() {
    if (pending != null) out.write(pending);
    pending = null;
  }

  for (final r in s.runes) {
    if (r >= 0xFF61 && r <= 0xFF9F) {
      final ch = map[r - 0xFF61];
      if (ch == '゛' && pending != null && dakuten.containsKey(pending)) {
        out.write(dakuten[pending]);
        pending = null;
      } else if (ch == '゜' && pending != null && handakuten.containsKey(pending)) {
        out.write(handakuten[pending]);
        pending = null;
      } else {
        flush();
        pending = ch;
      }
    } else {
      flush();
      out.writeCharCode(r);
    }
  }
  flush();
  return out.toString();
}

/// A product's name in [lang] from its names (0118: `{ja, en, zh, …}`), else
/// English, else the Japanese name — a name that has not been translated
/// still reads in a script the screen can draw.
String productNameIn(String lang, String name, {String? nameEn, Map<String, String> names = const {}}) {
  String? pick(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
  if (lang == 'ja') return widenKana(pick(names['ja']) ?? name);
  return pick(names[lang]) ?? pick(names['en']) ?? pick(nameEn) ?? widenKana(name);
}

/// A product's name for this screen's language: the name in that language
/// if the product has one (0118), the English one otherwise (0117), the
/// Japanese one on Japanese screens.
String productDisplayName(BuildContext context, String name, String? nameEn,
        {Map<String, String> names = const {}}) =>
    productNameIn(Localizations.localeOf(context).languageCode, name, nameEn: nameEn, names: names);

/// The product name, with the English one beneath it on Japanese screens.
class ProductNameText extends StatelessWidget {
  const ProductNameText({
    super.key,
    required this.name,
    this.nameEn,
    this.names = const {},
    this.style,
    this.maxLines,
  });

  final String name;
  final String? nameEn;
  final Map<String, String> names;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final en = (names['en'] ?? nameEn)?.trim();
    final main = Text(
      productDisplayName(context, name, nameEn, names: names),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
    if (!ja || en == null || en.isEmpty || en == name) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        Text(
          en,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
