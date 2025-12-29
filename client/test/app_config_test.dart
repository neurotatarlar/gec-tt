import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaz_tatar/app_config.dart';

class FakeAssetBundle extends AssetBundle {
  FakeAssetBundle({this.content, this.throwOnLoad = false});

  final String? content;
  final bool throwOnLoad;

  @override
  Future<ByteData> load(String key) async {
    if (throwOnLoad) {
      throw FlutterError('Asset not found');
    }
    final bytes = utf8.encode(content ?? '');
    final buffer = Uint8List.fromList(bytes).buffer;
    return ByteData.view(buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (throwOnLoad) {
      throw FlutterError('Asset not found');
    }
    return content ?? '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppConfigLoader returns defaults when asset missing', () async {
    final config = await AppConfigLoader.load(
      bundle: FakeAssetBundle(throwOnLoad: true),
    );

    expect(config.baseUrl, isEmpty);
    expect(config.appName, 'Yaz.Tatar!');
  });

  test('AppConfigLoader returns defaults when asset empty', () async {
    final config = await AppConfigLoader.load(
      bundle: FakeAssetBundle(content: ''),
    );

    expect(config.baseUrl, isEmpty);
    expect(config.appName, 'Yaz.Tatar!');
  });

  test('AppConfigLoader returns defaults when asset invalid', () async {
    final config = await AppConfigLoader.load(
      bundle: FakeAssetBundle(content: 'not-json'),
    );

    expect(config.baseUrl, isEmpty);
    expect(config.appName, 'Yaz.Tatar!');
  });
}
