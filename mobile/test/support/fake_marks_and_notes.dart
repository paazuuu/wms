import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/data/product_marks.dart';
import 'package:wms_mobile/features/shelf_notes/data/shelf_notes_repository.dart';

/// 0167's marks in memory: every call kept.
class FakeProductMarksRepository implements ProductMarksRepository {
  final calls = <(int, Set<String>, String?)>[];

  @override
  Future<ApiResult<void>> setMarks(int productId, Set<String> marks, {String? note}) async {
    calls.add((productId, marks, note));
    return const ApiSuccess(null);
  }
}

/// 0167's shelf notes in memory.
class FakeShelfNotesRepository implements ShelfNotesRepository {
  FakeShelfNotesRepository([List<ShelfNote>? notes]) : notes = notes ?? [];

  final List<ShelfNote> notes;
  var _next = 100;

  @override
  Future<ApiResult<List<ShelfNote>>> list() async => ApiSuccess(List.of(notes));

  @override
  Future<ApiResult<ShelfNote>> save({int? id, int? productId, String? location, required String body}) async {
    final n = ShelfNote(id: id ?? _next++, productId: productId, location: location, body: body, createdByName: '倉庫');
    notes
      ..removeWhere((x) => x.id == n.id)
      ..insert(0, n);
    return ApiSuccess(n);
  }

  @override
  Future<ApiResult<void>> remove(int id) async {
    notes.removeWhere((x) => x.id == id);
    return const ApiSuccess(null);
  }
}
