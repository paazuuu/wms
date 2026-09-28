import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product_image.dart';

/// The product library (0109). Files go straight to the private
/// `product-images` bucket (RLS: product.manage writes, anyone handling
/// goods reads), then are recorded with `add_product_image`.
abstract class ProductImageRepository {
  Future<ApiResult<List<LibraryProduct>>> library({String? query, bool withoutImages = false, int limit = 60, int offset = 0});
  Future<ApiResult<List<ProductImage>>> imagesOf(int productId);

  /// The face of each product asked for, by id and/or JAN.
  Future<ApiResult<List<ProductFace>>> faces({List<int> productIds = const [], List<String> jans = const []});

  /// Viewable URLs for storage paths (time-limited).
  Future<ApiResult<Map<String, String>>> signUrls(List<String> paths);

  Future<ApiResult<List<ProductImage>>> upload(
    int productId, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    bool first = false,
    String? caption,
  });

  /// Ids first to last; the first becomes the face.
  Future<ApiResult<List<ProductImage>>> reorder(int productId, List<int> ids);
  Future<ApiResult<List<ProductImage>>> withdraw(int imageId);
}

const productImageBucket = 'product-images';

class ProductImageRepositoryImpl implements ProductImageRepository {
  ProductImageRepositoryImpl({required Dio restDio, required Dio storageDio})
      : _rest = restDio,
        _storage = storageDio;

  final Dio _rest;
  final Dio _storage;

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

  List<ProductImage> _images(dynamic d) => [for (final r in _rows(d)) ProductImage.fromJson(r)];

  @override
  Future<ApiResult<List<LibraryProduct>>> library({String? query, bool withoutImages = false, int limit = 60, int offset = 0}) =>
      _rpc('product_library', {'p_query': query, 'p_without_images': withoutImages, 'p_limit': limit, 'p_offset': offset},
          (d) => [for (final r in _rows(d)) LibraryProduct.fromJson(r)]);

  @override
  Future<ApiResult<List<ProductImage>>> imagesOf(int productId) =>
      _rpc('product_images_of', {'p_product_id': productId}, _images);

  @override
  Future<ApiResult<List<ProductFace>>> faces({List<int> productIds = const [], List<String> jans = const []}) =>
      _rpc('product_thumbnails', {'p_product_ids': productIds, 'p_jans': jans},
          (d) => [for (final r in _rows(d)) ProductFace.fromJson(r)]);

  @override
  Future<ApiResult<Map<String, String>>> signUrls(List<String> paths) async {
    if (paths.isEmpty) return const ApiSuccess({});
    try {
      final r = await _storage.post('/object/sign/$productImageBucket', data: {'expiresIn': 3600, 'paths': paths});
      final out = <String, String>{};
      for (final e in (r.data as List? ?? const [])) {
        if (e is! Map) continue;
        final signed = e['signedURL'] as String?;
        if (signed == null || signed.isEmpty) continue;
        out['${e['path']}'] = '${_storage.options.baseUrl}$signed';
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<String, String>>(e);
    }
  }

  @override
  Future<ApiResult<List<ProductImage>>> upload(
    int productId, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    bool first = false,
    String? caption,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$productId/${DateTime.now().microsecondsSinceEpoch}_$safe';
    try {
      await _storage.post('/object/$productImageBucket/$path', data: bytes, options: Options(headers: {'Content-Type': contentType}));
    } on DioException catch (e) {
      return mapDioError<List<ProductImage>>(e);
    }
    return _rpc('add_product_image', {
      'p_product_id': productId,
      'p_storage_path': path,
      'p_content_type': contentType,
      'p_byte_size': bytes.length,
      'p_caption': caption,
      'p_first': first,
    }, _images);
  }

  @override
  Future<ApiResult<List<ProductImage>>> reorder(int productId, List<int> ids) =>
      _rpc('reorder_product_images', {'p_product_id': productId, 'p_ids': ids}, _images);

  @override
  Future<ApiResult<List<ProductImage>>> withdraw(int imageId) =>
      _rpc('withdraw_product_image', {'p_id': imageId}, _images);
}
