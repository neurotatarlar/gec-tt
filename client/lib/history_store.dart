import 'package:hive_flutter/hive_flutter.dart';

import 'models.dart';

class HistoryStore {
  static const _boxName = 'history';
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox<Map<String, dynamic>>(_boxName);
    _initialized = true;
  }

  Future<List<HistoryItem>> loadAll() async {
    await _ensureInit();
    final total = await count();
    return loadPage(offset: 0, limit: total);
  }

  Future<void> add(HistoryItem item) async {
    await _ensureInit();
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    await box.add(item.toJson());
  }

  Future<int> count() async {
    await _ensureInit();
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    return box.length;
  }

  Future<List<HistoryItem>> loadPage({
    required int offset,
    required int limit,
  }) async {
    await _ensureInit();
    if (limit <= 0) {
      return [];
    }
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    final values = box.values.toList(growable: false);
    final total = values.length;
    if (total == 0 || offset >= total) {
      return [];
    }
    final start = (total - offset - limit).clamp(0, total);
    final end = (total - offset).clamp(0, total);
    final slice = values.sublist(start, end).reversed;
    return slice
        .map((value) => HistoryItem.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  Future<void> clear() async {
    await _ensureInit();
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    await box.clear();
  }
}
