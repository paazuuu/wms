/// Lifecycle of a delivery plan (納品予定) as it moves from imported to
/// reconciled.
enum DeliveryPlanStatus {
  /// Imported from Excel, not yet checked against a physical delivery.
  open('open'),

  /// A reconciliation session is in progress.
  reconciling('reconciling'),

  /// Reconciliation submitted and closed.
  completed('completed');

  const DeliveryPlanStatus(this.wire);

  /// Value exchanged with the API.
  final String wire;

  static DeliveryPlanStatus fromWire(String? value) => switch (value) {
        'reconciling' => DeliveryPlanStatus.reconciling,
        'completed' => DeliveryPlanStatus.completed,
        _ => DeliveryPlanStatus.open,
      };
}
