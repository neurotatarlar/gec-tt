import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaz_tatar/app_state.dart';
import 'package:yaz_tatar/backend_client.dart';
import 'package:yaz_tatar/history_store.dart';
import 'package:yaz_tatar/i18n.dart';
import 'package:yaz_tatar/main.dart';
import 'package:yaz_tatar/models.dart';
import 'package:yaz_tatar/settings_store.dart';

class FakeBackendClient extends BackendClient {
  FakeBackendClient(this.stream) : super('http://localhost:3000');

  final Stream<SseEvent> stream;

  @override
  Stream<SseEvent> streamCorrect({
    required String text,
    required String lang,
    required String platform,
  }) {
    return stream;
  }
}

AppState _buildState({
  String baseUrl = 'http://localhost:3000',
  BackendClient? backend,
  Settings settings = const Settings.defaults(),
}) {
  return AppState(
    config: AppConfig(
      baseUrl: baseUrl,
      appName: 'Test App',
      reportEmail: '',
      reportTelegramUrl: '',
      appIdentifiers: const {},
    ),
    settingsStore: SettingsStore(),
    historyStore: HistoryStore(),
    settings: settings,
    history: const [],
    localizer: Localizer(),
    backend: backend,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        });
  });

  testWidgets('Corrected panel uses selectable text', (
    WidgetTester tester,
  ) async {
    final state = _buildState()..correctedText = 'fixed';

    await tester.pumpWidget(MyApp(appState: state));

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Expanded corrected panel hides original input', (
    WidgetTester tester,
  ) async {
    final state = _buildState()
      ..correctedText = 'fixed'
      ..expandedPanel = ExpandedPanel.corrected;

    await tester.pumpWidget(MyApp(appState: state));

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Error banner renders when errorMessage is set', (
    WidgetTester tester,
  ) async {
    final state = _buildState()..errorMessage = 'Server error';

    await tester.pumpWidget(MyApp(appState: state));

    expect(find.text('Server error'), findsOneWidget);
  });

  testWidgets('Layout toggle updates layout mode', (WidgetTester tester) async {
    final state = _buildState();

    await tester.pumpWidget(MyApp(appState: state));
    expect(state.settings.layoutMode, LayoutMode.horizontal);

    await tester.tap(find.byIcon(Icons.view_agenda));
    await tester.pump();

    expect(state.settings.layoutMode, LayoutMode.vertical);
  });

  testWidgets('Expand/collapse hides the other panel', (
    WidgetTester tester,
  ) async {
    final state = _buildState();

    await tester.pumpWidget(MyApp(appState: state));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);

    await tester.tap(find.byIcon(Icons.open_in_full).first);
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('Offline view renders when backend url missing', (
    WidgetTester tester,
  ) async {
    final state = _buildState(baseUrl: '');

    await tester.pumpWidget(MyApp(appState: state));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  testWidgets('Widget flow streams corrected text', (
    WidgetTester tester,
  ) async {
    final stream = Stream<SseEvent>.fromIterable([
      const SseEvent('meta', {'request_id': 'rid', 'model_backend': 'mock'}),
      const SseEvent('delta', {'text': 'he'}),
      const SseEvent('delta', {'text': 'llo'}),
      const SseEvent('done', {'latency_ms': 12}),
    ]);
    final backend = FakeBackendClient(stream);
    final settings = const Settings.defaults().copyWith(saveHistory: false);
    final state = _buildState(backend: backend, settings: settings);

    await tester.pumpWidget(MyApp(appState: state));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('hello'), findsWidgets);
    expect(state.correctedText, 'hello');
  });

  testWidgets('Copy button shows feedback', (WidgetTester tester) async {
    final state = _buildState()..correctedText = 'copied';

    await tester.pumpWidget(MyApp(appState: state));
    await tester.tap(find.byIcon(Icons.copy).first);
    await tester.pump();

    expect(find.text('actions.copied'), findsOneWidget);
  });
}
