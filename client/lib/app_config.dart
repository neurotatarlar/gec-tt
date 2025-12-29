import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

class AppConfigLoader {
  static Future<AppConfig> load({AssetBundle? bundle}) async {
    final loader = bundle ?? rootBundle;
    try {
      final raw = await loader.loadString('assets/config.json');
      if (raw.trim().isEmpty) {
        return AppConfig.fromJson(const {});
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return AppConfig.fromJson(data);
    } catch (_) {
      return AppConfig.fromJson(const {});
    }
  }
}
