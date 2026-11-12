import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/requirements/requirements_repository.dart';

/// 必須項目 (0212) in memory: every rule on, as a new system starts, unless
/// [off] names some; [canEdit] as for the system administrator.
class FakeRequirementsRepository implements RequirementsRepository {
  FakeRequirementsRepository({Set<String> off = const {}, this.canEdit = false}) : _off = {...off};

  final Set<String> _off;
  final bool canEdit;
  final List<(String, bool)> sets = [];

  @override
  Future<ApiResult<Requirements>> list() async => ApiSuccess(Requirements(canEdit: canEdit, rules: [
        for (final k in const [Req.receiptPrice, Req.shipPrice, Req.shipRate, Req.shipCard])
          RequirementRule(key: k, required: !_off.contains(k), isDefault: !_off.contains(k)),
      ]));

  @override
  Future<ApiResult<bool>> set(String key, bool required) async {
    sets.add((key, required));
    required ? _off.remove(key) : _off.add(key);
    return const ApiSuccess(true);
  }
}
