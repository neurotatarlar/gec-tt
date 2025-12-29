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
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    return box.values
        .whereType<Map<String, dynamic>>()
        .map(HistoryItem.fromJson)
        .toList();
  }

  Future<void> add(HistoryItem item) async {
    await _ensureInit();
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    await box.add(item.toJson());
  }

  Future<void> clear() async {
    await _ensureInit();
    final box = Hive.box<Map<String, dynamic>>(_boxName);
    await box.clear();
  }
}
