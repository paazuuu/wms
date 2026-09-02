import 'package:equatable/equatable.dart';

/// A JAN detected on a delivery-note photo by on-device OCR.
///
/// OCR is an assist, not a source of truth: it identifies which items appear on
/// the note (by JAN), and the operator confirms quantities by scanning or
/// typing. [quantityHint] is intentionally best-effort and often null.
class OcrLine extends Equatable {
  const OcrLine({
    required this.janCode,
    this.quantityHint,
    this.productName = '',
    this.rawText = '',
  });

  final String janCode;
  final int? quantityHint;

  /// Product name read from the note. Empty for the on-device parser (which only
  /// finds JANs); populated by the cloud vision OCR, which reads the whole row.
  final String productName;

  /// The recognized text line the JAN was found on, for operator context.
  final String rawText;

  @override
  List<Object?> get props => [janCode, quantityHint, productName];
}
