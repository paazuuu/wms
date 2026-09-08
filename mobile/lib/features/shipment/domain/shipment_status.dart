/// Lifecycle of a shipment (出庫) from imported list to shipped.
enum ShipmentStatus {
  /// Imported, not yet packed.
  open('open'),

  /// Cartons are being made up.
  packing('packing'),

  /// Confirmed and stock deducted.
  shipped('shipped'),

  /// Cancelled.
  cancelled('cancelled');

  const ShipmentStatus(this.wire);

  final String wire;

  static ShipmentStatus fromWire(String? value) => switch (value) {
        'packing' => ShipmentStatus.packing,
        'shipped' => ShipmentStatus.shipped,
        'cancelled' => ShipmentStatus.cancelled,
        _ => ShipmentStatus.open,
      };
}
