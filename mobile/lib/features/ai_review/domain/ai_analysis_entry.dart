import 'package:equatable/equatable.dart';

/// One extracted line from an OCR-shaped `ai_analysis.output_json` — the
/// only task type this app produces today (`ocr_delivery_note`). Other task
/// types would carry a different `output_json` shape; this screen only
/// knows how to render this one.
class AiOcrLine extends Equatable {
  const AiOcrLine({required this.janCode, this.productName, this.quantity});

  final String janCode;
  final String? productName;
  final int? quantity;

  factory AiOcrLine.fromJson(Map<String, dynamic> json) {
    final qty = json['quantity'];
    return AiOcrLine(
      janCode: (json['jan_code'] ?? '').toString(),
      productName: json['product_name'] as String?,
      quantity: qty is int ? qty : (qty is num ? qty.toInt() : null),
    );
  }

  @override
  List<Object?> get props => [janCode, productName, quantity];
}

/// One row of `list_ai_analysis` (0030) — a recorded AI call, pending human
/// review or already acted on (docs/ai_architecture.md §1: AI never commits
/// data directly; a person confirms or rejects it here first).
class AiAnalysisEntry extends Equatable {
  const AiAnalysisEntry({
    required this.id,
    required this.taskType,
    required this.provider,
    required this.status,
    required this.createdAt,
    this.model,
    this.confidence,
    this.lines = const [],
  });

  final int id;
  final String taskType;
  final String provider;
  final String? model;
  final double? confidence;

  /// PENDING_REVIEW | CONFIRMED | REJECTED
  final String status;
  final DateTime createdAt;
  final List<AiOcrLine> lines;

  factory AiAnalysisEntry.fromJson(Map<String, dynamic> json) {
    final output = json['output_json'] as Map<String, dynamic>?;
    final rawLines = output?['lines'] as List?;
    final confidenceRaw = json['confidence'];
    return AiAnalysisEntry(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      taskType: (json['task_type'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      model: json['model'] as String?,
      confidence: confidenceRaw is num ? confidenceRaw.toDouble() : null,
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0),
      lines: (rawLines ?? const [])
          .whereType<Map>()
          .map((e) => AiOcrLine.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [id, taskType, provider, model, confidence, status, createdAt, lines];
}
