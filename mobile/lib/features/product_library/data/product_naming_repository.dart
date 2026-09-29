import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product_naming.dart';

/// Our product format (0111): the naming templates, each product's naming
/// parts, renaming a maker or an attribute value everywhere, and registering
/// products from a read document in our format.
abstract class ProductNamingRepository {
  Future<ApiResult<List<NameFormat>>> formats();

  /// What names [template] would make (nothing written): the products using
  /// [formatId], or every built name when null.
  Future<ApiResult<List<NamePreview>>> preview(String template, {int? formatId, int limit = 20});

  /// Saves a format; every product using it is renamed.
  Future<ApiResult<NameFormatSaved>> saveFormat({int? id, required String name, required String template, bool? isDefault, bool? active});

  Future<ApiResult<ProductNaming>> naming(int productId);
  Future<ApiResult<ProductNaming>> setNaming(int productId, ProductNamingDraft draft);

  Future<ApiResult<List<MakerEntry>>> makers({String? search});

  /// The old name keeps reading as this maker; returns how many products follow.
  Future<ApiResult<int>> renameMaker(int makerId, String name);

  /// Calls a value something else everywhere; returns how many products changed.
  Future<ApiResult<int>> renameAttributeValue(int attributeId, String from, String to);

  /// The lines with no product yet, as products in our format.
  Future<ApiResult<List<ProductProposal>>> propose(int? partnerId, List<Map<String, dynamic>> lines);
  Future<ApiResult<List<RegisteredProduct>>> register(int? partnerId, List<ProductProposal> items, {int? formatId});
}

class ProductNamingRepositoryImpl implements ProductNamingRepository {
  ProductNamingRepositoryImpl(this._rest);

  final Dio _rest;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(dynamic) parse) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(parse(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic d) {
    final list = d is List && d.length == 1 && d.first is List ? d.first as List : (d is List ? d : const []);
    return [for (final e in list) if (e is Map) e.cast<String, dynamic>()];
  }

  Map<String, dynamic> _one(dynamic d) {
    final m = d is List && d.length == 1 ? d.first : d;
    return m is Map ? m.cast<String, dynamic>() : const {};
  }

  int _count(dynamic d, String key) {
    final v = _one(d)[key];
    return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  }

  List<NameFormat> _formats(dynamic d) => [for (final r in _rows(d)) NameFormat.fromJson(r)];

  @override
  Future<ApiResult<List<NameFormat>>> formats() => _rpc('list_name_formats', {}, _formats);

  @override
  Future<ApiResult<List<NamePreview>>> preview(String template, {int? formatId, int limit = 20}) =>
      _rpc('preview_name_format', {'p_template': template, 'p_format_id': formatId, 'p_limit': limit},
          (d) => [for (final r in _rows(d)) NamePreview.fromJson(r)]);

  @override
  Future<ApiResult<NameFormatSaved>> saveFormat({int? id, required String name, required String template, bool? isDefault, bool? active}) =>
      _rpc('save_name_format', {
        'p': {
          'id': id,
          'name': name,
          'template': template,
          if (isDefault != null) 'is_default': isDefault,
          if (active != null) 'status': active ? 'active' : 'inactive',
        },
      }, (d) {
        final m = _one(d);
        return NameFormatSaved(
          id: (m['id'] as num?)?.toInt() ?? 0,
          renamed: (m['renamed'] as num?)?.toInt() ?? 0,
          formats: _formats(m['formats']),
        );
      });

  @override
  Future<ApiResult<ProductNaming>> naming(int productId) =>
      _rpc('product_naming', {'p_product_id': productId}, (d) => ProductNaming.fromJson(_one(d)));

  @override
  Future<ApiResult<ProductNaming>> setNaming(int productId, ProductNamingDraft draft) =>
      _rpc('set_product_naming', {'p_product_id': productId, 'p': draft.toJson()}, (d) => ProductNaming.fromJson(_one(d)));

  @override
  Future<ApiResult<List<MakerEntry>>> makers({String? search}) =>
      _rpc('list_makers', {'p_search': search}, (d) => [for (final r in _rows(d)) MakerEntry.fromJson(r)]);

  @override
  Future<ApiResult<int>> renameMaker(int makerId, String name) =>
      _rpc('rename_maker', {'p_id': makerId, 'p_name': name}, (d) => _count(d, 'products'));

  @override
  Future<ApiResult<int>> renameAttributeValue(int attributeId, String from, String to) =>
      _rpc('rename_attribute_value', {'p_attribute_id': attributeId, 'p_from': from, 'p_to': to},
          (d) => _count(d, 'products'));

  @override
  Future<ApiResult<List<ProductProposal>>> propose(int? partnerId, List<Map<String, dynamic>> lines) =>
      _rpc('propose_products_from_lines', {'p_partner_id': partnerId, 'p_lines': lines},
          (d) => [for (final r in _rows(d)) ProductProposal.fromJson(r)]);

  @override
  Future<ApiResult<List<RegisteredProduct>>> register(int? partnerId, List<ProductProposal> items, {int? formatId}) =>
      _rpc('register_products', {
        'p_partner_id': partnerId,
        'p_items': [for (final i in items) i.toRegisterJson()],
        'p_format_id': formatId,
      }, (d) => [for (final r in _rows(d)) RegisteredProduct.fromJson(r)]);
}
