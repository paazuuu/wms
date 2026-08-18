/// The reason category for a stock adjustment, matching the backend's
/// `in:manual,count,damage,return,transfer` validation. `returned` avoids the
/// reserved Dart keyword while keeping the wire value `return`.
enum AdjustmentType {
  manual('manual', 'Manual'),
  count('count', 'Count'),
  damage('damage', 'Damage'),
  returned('return', 'Return'),
  transfer('transfer', 'Transfer');

  const AdjustmentType(this.wire, this.label);

  /// Value sent to / received from the API.
  final String wire;

  /// Human-readable label for the UI.
  final String label;

  static AdjustmentType fromWire(String? value) => switch (value) {
        'count' => AdjustmentType.count,
        'damage' => AdjustmentType.damage,
        'return' => AdjustmentType.returned,
        'transfer' => AdjustmentType.transfer,
        _ => AdjustmentType.manual,
      };
}
