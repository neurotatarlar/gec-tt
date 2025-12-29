import 'package:flutter/material.dart';

enum LayoutMode { horizontal, vertical }

enum ExpandedPanel { none, original, corrected }

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.appName,
    required this.reportEmail,
    required this.reportTelegramUrl,
    required this.appIdentifiers,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final identifiers = <String, String>{};
    final rawIdentifiers = json['appIdentifiers'];
    if (rawIdentifiers is Map) {
      rawIdentifiers.forEach((key, value) {
        if (key is String && value != null) {
          identifiers[key] = value.toString();
        }
      });
    }

    return AppConfig(
      baseUrl: (json['baseUrl'] ?? '').toString(),
      appName: (json['appName'] ?? 'Yaz.Tatar!').toString(),
      reportEmail: (json['reportEmail'] ?? '').toString(),
      reportTelegramUrl: (json['reportTelegramUrl'] ?? '').toString(),
      appIdentifiers: identifiers,
    );
  }
  final String baseUrl;
  final String appName;
  final String reportEmail;
  final String reportTelegramUrl;
  final Map<String, String> appIdentifiers;
}

class Settings {
  const Settings({
    required this.themeMode,
    required this.fontScale,
    required this.autoScroll,
    required this.saveHistory,
    required this.language,
    required this.layoutMode,
  });

  const Settings.defaults()
    : themeMode = ThemeMode.system,
      fontScale = 1.0,
      autoScroll = true,
      saveHistory = true,
      language = 'en',
      layoutMode = LayoutMode.horizontal;
  final ThemeMode themeMode;
  final double fontScale;
  final bool autoScroll;
  final bool saveHistory;
  final String language;
  final LayoutMode layoutMode;

  Settings copyWith({
    ThemeMode? themeMode,
    double? fontScale,
    bool? autoScroll,
    bool? saveHistory,
    String? language,
    LayoutMode? layoutMode,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      autoScroll: autoScroll ?? this.autoScroll,
      saveHistory: saveHistory ?? this.saveHistory,
      language: language ?? this.language,
      layoutMode: layoutMode ?? this.layoutMode,
    );
  }
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.original,
    required this.corrected,
    required this.timestamp,
    required this.latencyMs,
    required this.requestId,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id']?.toString() ?? '',
      original: json['original']?.toString() ?? '',
      corrected: json['corrected']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      latencyMs: (json['latencyMs'] ?? 0) as int,
      requestId: json['requestId']?.toString() ?? '',
    );
  }
  final String id;
  final String original;
  final String corrected;
  final DateTime timestamp;
  final int latencyMs;
  final String requestId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original': original,
      'corrected': corrected,
      'timestamp': timestamp.toIso8601String(),
      'latencyMs': latencyMs,
      'requestId': requestId,
    };
  }
}

class SseEvent {
  const SseEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
}
