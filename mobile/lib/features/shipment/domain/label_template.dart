import 'package:equatable/equatable.dart';

/// A print label built from a `{{variable}}` template (UI spec §20).
///
/// Kept as data rather than hard-coded HTML so the label a warehouse actually
/// wants — carton, product, inbound, shelf, pallet — is a template choice, not
/// a code change. Rendering is deliberately dumb: substitute, then drop the
/// lines that came out empty, so a template can list a field (lot, spec) that
/// this particular shipment does not have without leaving a dangling label.
class LabelTemplate extends Equatable {
  const LabelTemplate({
    required this.id,
    required this.name,
    required this.lines,
    this.codeVariable = '{{jan}}',
    this.qrVariable,
  });

  /// Stable identifier, used to remember the operator's choice.
  final String id;

  /// Human name as shown in the picker (localized by the caller for the
  /// built-ins; a user-defined template would carry its own).
  final String name;

  /// The label's text rows, top to bottom, each a template string. A row whose
  /// variables all resolve empty is dropped.
  final List<String> lines;

  /// Template for the 1-D barcode (Code128/EAN-13), or null for no barcode.
  final String? codeVariable;

  /// Template for the QR payload, or null for no QR. §17 wants every carton to
  /// carry its own code, so the carton template sets this.
  final String? qrVariable;

  /// Every variable §20 defines. Missing keys render as empty, never as the
  /// literal `{{name}}` — a label with `{{lot}}` printed on it is worse than
  /// one with the row left out.
  static const List<String> variables = [
    'product_name',
    'jan',
    'sku',
    'lot',
    'quantity',
    'carton_no',
    'carton_total',
    'shipment_no',
    'warehouse',
    'company',
    'customer',
  ];

  static final RegExp _token = RegExp(r'\{\{\s*(\w+)\s*\}\}');

  /// Substitute [values] into [template]. Unknown or null values become ''.
  static String fill(String template, Map<String, String?> values) =>
      template.replaceAllMapped(
          _token, (m) => values[m.group(1)]?.trim() ?? '');

  /// The text rows for one label, with rows that say nothing removed.
  ///
  /// A row is dropped when it has variables and *every* one of them resolved
  /// empty — otherwise a template row like `ロット {{lot}}` would print its own
  /// label with nothing after it on a shipment that has no lot. A row with no
  /// variables at all is static text and always kept.
  List<String> render(Map<String, String?> values) {
    final out = <String>[];
    for (final line in lines) {
      final filled = fill(line, values).trim();
      if (filled.isEmpty) continue;
      final tokens = _token.allMatches(line).map((m) => m.group(1)!);
      if (tokens.isNotEmpty &&
          tokens.every((t) => (values[t] ?? '').trim().isEmpty)) {
        continue;
      }
      out.add(filled);
    }
    return out;
  }

  String? renderCode(Map<String, String?> values) {
    final v = codeVariable;
    if (v == null) return null;
    final out = fill(v, values).trim();
    return out.isEmpty ? null : out;
  }

  String? renderQr(Map<String, String?> values) {
    final v = qrVariable;
    if (v == null) return null;
    final out = fill(v, values).trim();
    return out.isEmpty ? null : out;
  }

  @override
  List<Object?> get props => [id, name, lines, codeVariable, qrVariable];
}

/// The built-in templates §20 lists. Names are ids here and localized at the
/// point of display, so the set is available without a BuildContext.
class LabelTemplates {
  const LabelTemplates._();

  /// 標準箱ラベル — what goes on the outside of a carton (§17/§19).
  ///
  /// The QR carries the carton's identity rather than a URL: scanning it at the
  /// dock has to work with no network, and "which box is this" is the question
  /// being asked.
  static const carton = LabelTemplate(
    id: 'carton',
    name: '標準箱ラベル',
    lines: [
      '{{company}}',
      '{{customer}}',
      '出庫 {{shipment_no}}',
      '箱 {{carton_no}} / {{carton_total}}',
      '{{product_name}}',
      'JAN {{jan}}',
      '数量 {{quantity}}',
      'ロット {{lot}}',
      '{{warehouse}}',
    ],
    codeVariable: '{{jan}}',
    qrVariable: 'SHP:{{shipment_no}}|BOX:{{carton_no}}/{{carton_total}}',
  );

  /// Only the carton label is wired to a flow today. Product / inbound / shelf /
  /// pallet labels are named in §20 but nothing prints them yet, and defining
  /// them here before a screen uses them would be exactly the fake completeness
  /// §53 warns about — they get added with the flows that need them.
}
