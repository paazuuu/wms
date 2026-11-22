import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/admin/data/card_erase_repository.dart';

/// Cards erased in memory (0228): the checks given, the erasures asked.
class FakeCardEraseRepository implements CardEraseRepository {
  FakeCardEraseRepository({this.partners = const {}, this.overseas = const {}});

  final Map<int, PartnerEraseCheck> partners;
  final Map<int, OverseasEraseCheck> overseas;
  final erased = <(String, int)>[];

  @override
  Future<ApiResult<PartnerEraseCheck>> partnerCheck(int id) async =>
      ApiSuccess(partners[id] ?? PartnerEraseCheck(id: id, name: '#$id'));

  @override
  Future<ApiResult<OverseasEraseCheck>> overseasCheck(int id) async =>
      ApiSuccess(overseas[id] ?? OverseasEraseCheck(id: id, name: '#$id'));

  @override
  Future<ApiResult<bool>> erase(String kind, int id) async {
    erased.add((kind, id));
    return const ApiSuccess(true);
  }
}
