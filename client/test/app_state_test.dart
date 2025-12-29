import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaz_tatar/app_state.dart';
import 'package:yaz_tatar/history_store.dart';
import 'package:yaz_tatar/i18n.dart';
import 'package:yaz_tatar/models.dart';
import 'package:yaz_tatar/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppState buildState() {
    return AppState(
      config: const AppConfig(
        baseUrl: 'http://localhost:3000',
        appName: 'Test App',
        reportEmail: '',
        reportTelegramUrl: '',
        appIdentifiers: {},
      ),
      settingsStore: SettingsStore(),
      historyStore: HistoryStore(),
      settings: const Settings.defaults(),
      history: const [],
      localizer: Localizer(),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('toggleExpand cycles panel state', () {
    final state = buildState();

    expect(state.expandedPanel, ExpandedPanel.none);

    state.toggleExpand(ExpandedPanel.original);
    expect(state.expandedPanel, ExpandedPanel.original);

    state.toggleExpand(ExpandedPanel.original);
    expect(state.expandedPanel, ExpandedPanel.none);

    state.toggleExpand(ExpandedPanel.corrected);
    expect(state.expandedPanel, ExpandedPanel.corrected);
  });

  test('setSplitRatio updates ratio', () {
    final state = buildState()..setSplitRatio(0.7);
    expect(state.splitRatio, 0.7);
  });

  test('setLayout resets split ratio', () {
    final state = buildState()
      ..splitRatio = 0.7
      ..setLayout(LayoutMode.vertical);
    expect(state.settings.layoutMode, LayoutMode.vertical);
    expect(state.splitRatio, 0.5);
  });
}
