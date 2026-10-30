import 'package:equatable/equatable.dart';

import '../../tax_files/domain/tax_purchases.dart';

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

/// Where a payment goes (振込先): the bank, branch, 普通 or 当座, the account
/// number and the name on it (0171).
class Payee extends Equatable {
  const Payee({this.bank, this.branch, this.accountType, this.accountNumber, this.holder});

  final String? bank;
  final String? branch;
  final String? accountType;
  final String? accountNumber;
  final String? holder;

  bool get isEmpty => [bank, branch, accountType, accountNumber, holder].every((v) => v == null);

  static Payee? fromJson(Object? j) {
    if (j is! Map) return null;
    final p = Payee(
      bank: _s(j['bank']),
      branch: _s(j['branch']),
      accountType: _s(j['account_type']),
      accountNumber: _s(j['account_number']),
      holder: _s(j['holder']),
    );
    return p.isEmpty ? null : p;
  }

  Map<String, dynamic> toJson() => {
        if (bank != null) 'bank': bank,
        if (branch != null) 'branch': branch,
        if (accountType != null) 'account_type': accountType,
        if (accountNumber != null) 'account_number': accountNumber,
        if (holder != null) 'holder': holder,
      };

  /// One line to copy into a bank's transfer screen.
  String get line => [bank, branch, accountType, accountNumber, holder].whereType<String>().join(' ');

  @override
  List<Object?> get props => [bank, branch, accountType, accountNumber, holder];
}

/// A transfer's proof: a screenshot or PDF kept beside the payment.
class PaymentProof extends Equatable {
  const PaymentProof({required this.id, required this.path, required this.name, this.contentType, this.createdAt, this.createdByName});

  final int id;
  final String path;
  final String name;
  final String? contentType;
  final DateTime? createdAt;
  final String? createdByName;

  bool get isImage =>
      (contentType ?? '').startsWith('image/') || RegExp(r'\.(png|jpe?g|webp|gif|heic)$', caseSensitive: false).hasMatch(name);

  factory PaymentProof.fromJson(Map<String, dynamic> j) => PaymentProof(
        id: (j['id'] as num).toInt(),
        path: '${j['storage_path']}',
        name: _s(j['file_name']) ?? '${j['storage_path']}',
        contentType: _s(j['content_type']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        createdByName: _s(j['created_by_name']),
      );

  @override
  List<Object?> get props => [id, path, name, contentType, createdAt];
}

/// Where the 振込先 shown came from.
enum PayeeSource { invoice, supplier, none }

/// One payment to make (0171): an invoice taken into stock — its figures as
/// in 税理士用ファイル — with the supplier, its 振込先, whether it is paid
/// (the import's own 支払い済) and the proofs of the transfer.
class Payment extends Equatable {
  const Payment({
    required this.purchase,
    this.supplierId,
    this.supplierDisplayName,
    this.payee,
    this.payeeSource = PayeeSource.none,
    this.supplierAccount,
    this.paidAt,
    this.paidByName,
    this.proofs = const [],
  });

  final TaxPurchase purchase;
  final int? supplierId;
  final String? supplierDisplayName;
  final Payee? payee;
  final PayeeSource payeeSource;

  /// The supplier's own 振込先 as kept (to edit).
  final Payee? supplierAccount;
  final DateTime? paidAt;
  final String? paidByName;
  final List<PaymentProof> proofs;

  int get importId => purchase.importId;
  bool get paid => purchase.paid;
  String get supplierName => supplierDisplayName ?? purchase.supplierName ?? '';

  /// What to transfer: the invoice's own total when it was read, else the
  /// lines' 税込.
  double get amount => purchase.docTotal ?? purchase.gross;

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        purchase: TaxPurchase.fromJson(j),
        supplierId: (j['supplier_id'] as num?)?.toInt(),
        supplierDisplayName: _s(j['supplier_display_name']),
        payee: Payee.fromJson(j['payee']),
        payeeSource: switch (j['payee_source']) {
          'invoice' => PayeeSource.invoice,
          'supplier' => PayeeSource.supplier,
          _ => PayeeSource.none,
        },
        supplierAccount: Payee.fromJson(j['supplier_bank_account']),
        paidAt: DateTime.tryParse('${j['paid_at'] ?? ''}')?.toLocal(),
        paidByName: _s(j['paid_by_name']),
        proofs: [
          for (final p in (j['proofs'] as List? ?? const []).whereType<Map>()) PaymentProof.fromJson(p.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [purchase, supplierId, payee, payeeSource, paidAt, proofs];
}
