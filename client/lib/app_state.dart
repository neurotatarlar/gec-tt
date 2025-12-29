import 'dart:async';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'backend_client.dart';
import 'history_store.dart';
import 'i18n.dart';
import 'models.dart';
import 'settings_store.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.config,
    required this.settingsStore,
    required this.historyStore,
    required this.settings,
    required this.history,
    required Localizer localizer,
    BackendClient? backend,
  }) : _localizer = localizer,
       _backend = backend ?? BackendClient(config.baseUrl);

  final AppConfig config;
  final SettingsStore settingsStore;
  final HistoryStore historyStore;
  final Localizer _localizer;
  final BackendClient _backend;

  Settings settings;
  List<HistoryItem> history;
  String originalText = '';
  String correctedText = '';
  String? requestId;
  String? modelBackend;
  bool isStreaming = false;
  String statusText = '';
  String? errorMessage;
  ExpandedPanel expandedPanel = ExpandedPanel.none;
  double splitRatio = 0.5;

  Timer? _debounce;
  StreamSubscription<SseEvent>? _subscription;
  String _lastRequestedText = '';

  String t(String key, {Map<String, String> vars = const {}}) =>
      _localizer.t(key, vars: vars);

  Future<void> setLanguage(String lang) async {
    await _localizer.load(lang);
    settings = settings.copyWith(language: lang);
    await settingsStore.save(settings);
    notifyListeners();
  }

  Future<void> updateSettings(Settings updated) async {
    settings = updated;
    await settingsStore.save(settings);
    notifyListeners();
  }

  void setLayout(LayoutMode mode) {
    settings = settings.copyWith(layoutMode: mode);
    settingsStore.save(settings);
    resetSplit();
    notifyListeners();
  }

  void setSplitRatio(double ratio) {
    splitRatio = ratio.clamp(0.2, 0.8);
    notifyListeners();
  }

  void toggleExpand(ExpandedPanel panel) {
    if (expandedPanel == panel) {
      expandedPanel = ExpandedPanel.none;
    } else {
      expandedPanel = panel;
    }
    notifyListeners();
  }

  void resetSplit() {
    splitRatio = 0.5;
  }

  void updateOriginalText(String text) {
    originalText = text;
    if (isStreaming) {
      _subscription?.cancel();
      _subscription = null;
      isStreaming = false;
      statusText = '';
    }
    if (statusText.isNotEmpty) {
      statusText = '';
    }
    errorMessage = null;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _startStreaming);
  }

  Future<void> loadHistoryItem(HistoryItem item) async {
    originalText = item.original;
    correctedText = item.corrected;
    isStreaming = false;
    statusText = '';
    requestId = item.requestId;
    modelBackend = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = [];
    await historyStore.clear();
    notifyListeners();
  }

  Future<void> _startStreaming() async {
    final text = originalText.trim();
    if (text.isEmpty) {
      await _subscription?.cancel();
      _subscription = null;
      correctedText = '';
      statusText = '';
      isStreaming = false;
      errorMessage = null;
      _lastRequestedText = '';
      notifyListeners();
      return;
    }
    if (config.baseUrl.isEmpty) {
      await _subscription?.cancel();
      _subscription = null;
      errorMessage = _localizer.t('errors.noBackendUrl');
      statusText = '';
      isStreaming = false;
      notifyListeners();
      return;
    }
    if (text == _lastRequestedText) {
      return;
    }
    _lastRequestedText = text;
    await _subscription?.cancel();

    correctedText = '';
    requestId = null;
    statusText = t('status.correcting');
    errorMessage = null;
    modelBackend = null;
    isStreaming = true;
    notifyListeners();

    _subscription = _backend
        .streamCorrect(text: text, lang: 'tt', platform: 'flutter')
        .listen(_handleEvent, onError: _handleError, onDone: _handleDone);
  }

  void _handleEvent(SseEvent event) {
    if (event.event == 'meta') {
      requestId = event.data['request_id']?.toString();
      modelBackend = event.data['model_backend']?.toString();
      notifyListeners();
      return;
    }
    if (event.event == 'delta') {
      correctedText += event.data['text']?.toString() ?? '';
      notifyListeners();
      return;
    }
    if (event.event == 'done') {
      final rawLatency = event.data['latency_ms'];
      final latency = rawLatency is int
          ? rawLatency
          : int.tryParse(rawLatency?.toString() ?? '') ?? 0;
      _finishStream(latency: latency);
    }
    if (event.event == 'error') {
      errorMessage = event.data['message']?.toString() ?? t('errors.stream');
      statusText = t('status.error');
      isStreaming = false;
      notifyListeners();
    }
  }

  void _handleError(Object error) {
    errorMessage = error.toString();
    statusText = t('status.error');
    isStreaming = false;
    notifyListeners();
  }

  void _handleDone() {
    if (isStreaming) {
      _finishStream(latency: 0);
    }
  }

  Future<void> _finishStream({required int latency}) async {
    isStreaming = false;
    statusText = t('status.done');
    notifyListeners();

    if (settings.saveHistory) {
      final item = HistoryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        original: originalText,
        corrected: correctedText,
        timestamp: DateTime.now(),
        latencyMs: latency,
        requestId: requestId ?? '',
      );
      history.insert(0, item);
      await historyStore.add(item);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

Future<AppState> bootstrapAppState() async {
  final config = await AppConfigLoader.load();
  final settingsStore = SettingsStore();
  final historyStore = HistoryStore();
  final settings = await settingsStore.load();
  final history = await historyStore.loadAll();
  final localizer = Localizer();
  await localizer.load(settings.language);

  return AppState(
    config: config,
    settingsStore: settingsStore,
    historyStore: historyStore,
    settings: settings,
    history: history,
    localizer: localizer,
  );
}
