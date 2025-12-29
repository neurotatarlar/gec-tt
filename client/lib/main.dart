import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = await bootstrapAppState();
  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.appState, super.key});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: state.config.appName,
            debugShowCheckedModeBanner: false,
            themeMode: state.settings.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFC19A42),
              ),
              textTheme: Theme.of(
                context,
              ).textTheme.apply(fontSizeFactor: state.settings.fontScale),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFC19A42),
                brightness: Brightness.dark,
              ),
              textTheme: Theme.of(
                context,
              ).textTheme.apply(fontSizeFactor: state.settings.fontScale),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _originalController = TextEditingController();
  final ScrollController _correctedScroll = ScrollController();

  @override
  void dispose() {
    _originalController.dispose();
    _correctedScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _syncOriginalController(state);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(state: state),
            _LayoutControls(state: state),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SplitPanels(
                  state: state,
                  originalController: _originalController,
                  correctedScroll: _correctedScroll,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _BottomBar(state: state),
          ],
        ),
      ),
    );
  }

  void _syncOriginalController(AppState state) {
    if (_originalController.text != state.originalText) {
      _originalController.text = state.originalText;
      _originalController.selection = TextSelection.fromPosition(
        TextPosition(offset: _originalController.text.length),
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            state.config.appName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: state.settings.language,
            items: [
              DropdownMenuItem(
                value: 'en',
                child: Text(state.t('language.en')),
              ),
              DropdownMenuItem(
                value: 'tt',
                child: Text(state.t('language.tt')),
              ),
              DropdownMenuItem(
                value: 'ru',
                child: Text(state.t('language.ru')),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              state.setLanguage(value);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => _SettingsSheet(state: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutControls extends StatelessWidget {
  const _LayoutControls({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconToggle(
            icon: Icons.view_column,
            active: state.settings.layoutMode == LayoutMode.horizontal,
            onPressed: () => state.setLayout(LayoutMode.horizontal),
          ),
          const SizedBox(width: 10),
          _IconToggle(
            icon: Icons.view_agenda,
            active: state.settings.layoutMode == LayoutMode.vertical,
            onPressed: () => state.setLayout(LayoutMode.vertical),
          ),
        ],
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? Colors.black87 : Colors.black26),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _SplitPanels extends StatelessWidget {
  const _SplitPanels({
    required this.state,
    required this.originalController,
    required this.correctedScroll,
  });

  final AppState state;
  final TextEditingController originalController;
  final ScrollController correctedScroll;

  @override
  Widget build(BuildContext context) {
    if (state.expandedPanel != ExpandedPanel.none) {
      return _ExpandedPanelView(
        state: state,
        originalController: originalController,
        correctedScroll: correctedScroll,
      );
    }

    final isVertical = state.settings.layoutMode == LayoutMode.vertical;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalExtent = isVertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final firstFlex = (state.splitRatio * 1000).round();
        final secondFlex = 1000 - firstFlex;
        final children = <Widget>[
          Expanded(
            flex: firstFlex,
            child: _OriginalPanel(state: state, controller: originalController),
          ),
          _SplitDivider(
            isVertical: isVertical,
            state: state,
            totalExtent: totalExtent,
          ),
          Expanded(
            flex: secondFlex,
            child: _CorrectedPanel(
              state: state,
              scrollController: correctedScroll,
            ),
          ),
        ];
        return isVertical
            ? Column(children: children)
            : Row(children: children);
      },
    );
  }
}

class _ExpandedPanelView extends StatelessWidget {
  const _ExpandedPanelView({
    required this.state,
    required this.originalController,
    required this.correctedScroll,
  });

  final AppState state;
  final TextEditingController originalController;
  final ScrollController correctedScroll;

  @override
  Widget build(BuildContext context) {
    final panel = state.expandedPanel == ExpandedPanel.original
        ? _OriginalPanel(state: state, controller: originalController)
        : _CorrectedPanel(state: state, scrollController: correctedScroll);
    return Column(children: [Expanded(child: panel)]);
  }
}

class _SplitDivider extends StatelessWidget {
  const _SplitDivider({
    required this.isVertical,
    required this.state,
    required this.totalExtent,
  });

  final bool isVertical;
  final AppState state;
  final double totalExtent;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: isVertical
          ? SystemMouseCursors.resizeRow
          : SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: isVertical
            ? null
            : (details) {
                final extent = totalExtent <= 0 ? 1 : totalExtent;
                final ratioDelta = details.delta.dx / extent;
                state.setSplitRatio(state.splitRatio + ratioDelta);
              },
        onVerticalDragUpdate: isVertical
            ? (details) {
                final extent = totalExtent <= 0 ? 1 : totalExtent;
                final ratioDelta = details.delta.dy / extent;
                state.setSplitRatio(state.splitRatio + ratioDelta);
              }
            : null,
        child: Container(
          width: isVertical ? double.infinity : 10,
          height: isVertical ? 10 : double.infinity,
          margin: isVertical
              ? const EdgeInsets.symmetric(vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _OriginalPanel extends StatelessWidget {
  const _OriginalPanel({required this.state, required this.controller});

  final AppState state;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '',
      actions: [
        IconButton(
          icon: Icon(
            state.expandedPanel == ExpandedPanel.original
                ? Icons.close_fullscreen
                : Icons.open_in_full,
          ),
          onPressed: () => state.toggleExpand(ExpandedPanel.original),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => _copyToClipboard(context, state, controller.text),
        ),
      ],
      child: TextField(
        controller: controller,
        expands: true,
        maxLines: null,
        onChanged: state.updateOriginalText,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}

class _CorrectedPanel extends StatefulWidget {
  const _CorrectedPanel({required this.state, required this.scrollController});

  final AppState state;
  final ScrollController scrollController;

  @override
  State<_CorrectedPanel> createState() => _CorrectedPanelState();
}

class _CorrectedPanelState extends State<_CorrectedPanel> {
  @override
  void didUpdateWidget(covariant _CorrectedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _autoScroll();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return _PanelShell(
      title: state.statusText,
      actions: [
        if (state.isStreaming)
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        IconButton(
          icon: Icon(
            state.expandedPanel == ExpandedPanel.corrected
                ? Icons.close_fullscreen
                : Icons.open_in_full,
          ),
          onPressed: () => state.toggleExpand(ExpandedPanel.corrected),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () =>
              _copyToClipboard(context, state, state.correctedText),
        ),
      ],
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2EA),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: SelectableText(
                state.correctedText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          if (state.errorMessage != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _ErrorBanner(message: state.errorMessage!),
            ),
        ],
      ),
    );
  }

  void _autoScroll() {
    if (!widget.state.settings.autoScroll || !widget.state.isStreaming) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.scrollController.jumpTo(
        widget.scrollController.position.maxScrollExtent,
      );
    });
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.actions,
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

void _copyToClipboard(BuildContext context, AppState state, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(state.t('actions.copied')),
        duration: const Duration(milliseconds: 1200),
      ),
    );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          TextButton(
            onPressed: () => _openHistory(context, state),
            child: Text(state.t('history.title')),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _openReport(context, state),
            child: Text(state.t('actions.report')),
          ),
        ],
      ),
    );
  }

  void _openHistory(BuildContext context, AppState state) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _HistorySheet(state: state),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: _HistorySheet(state: state)),
      );
    }
  }

  void _openReport(BuildContext context, AppState state) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _ReportSheet(state: state),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: _ReportSheet(state: state)),
      );
    }
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.t('settings.title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _ThemeSelector(state: state),
          const SizedBox(height: 12),
          _FontSizeSelector(state: state),
          const SizedBox(height: 12),
          SwitchListTile(
            value: state.settings.autoScroll,
            title: Text(state.t('settings.autoScroll')),
            onChanged: (value) => state.updateSettings(
              state.settings.copyWith(autoScroll: value),
            ),
          ),
          SwitchListTile(
            value: state.settings.saveHistory,
            title: Text(state.t('settings.saveHistory')),
            onChanged: (value) => state.updateSettings(
              state.settings.copyWith(saveHistory: value),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: state.clearHistory,
            child: Text(state.t('settings.clearHistory')),
          ),
        ],
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final requestId = state.requestId?.isNotEmpty ?? false
        ? state.requestId!
        : state.t('report.notAvailable');
    final hasEmail = state.config.reportEmail.isNotEmpty;
    final hasTelegram = state.config.reportTelegramUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.t('report.title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(state.t('report.body')),
          const SizedBox(height: 12),
          SelectableText(
            state.t('report.requestId', vars: {'requestId': requestId}),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: hasEmail ? () => _launchEmail(context) : null,
                icon: const Icon(Icons.email_outlined),
                label: Text(state.t('report.email')),
              ),
              OutlinedButton.icon(
                onPressed: hasTelegram ? () => _launchTelegram(context) : null,
                icon: const Icon(Icons.send_outlined),
                label: Text(state.t('report.telegram')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(state.t('actions.close')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final uri = _buildEmailUri();
    await _launchExternal(context, uri);
  }

  Future<void> _launchTelegram(BuildContext context) async {
    final uri = Uri.parse(state.config.reportTelegramUrl);
    await _launchExternal(context, uri);
  }

  Uri _buildEmailUri() {
    final requestId = state.requestId?.isNotEmpty ?? false
        ? state.requestId!
        : state.t('report.notAvailable');
    final timestamp = DateTime.now().toIso8601String();
    final backend =
        (state.modelBackend != null && state.modelBackend!.isNotEmpty)
        ? state.modelBackend!
        : (state.config.baseUrl.isNotEmpty
              ? state.config.baseUrl
              : state.t('report.unknown'));
    final subject = state.t(
      'report.emailSubject',
      vars: {'appName': state.config.appName},
    );
    final body = state.t(
      'report.emailBody',
      vars: {
        'requestId': requestId,
        'timestamp': timestamp,
        'backend': backend,
      },
    );

    return Uri(
      scheme: 'mailto',
      path: state.config.reportEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
  }

  Future<void> _launchExternal(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('errors.openLink'))));
    }
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.t('settings.theme')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(state.t('settings.light')),
              selected: state.settings.themeMode == ThemeMode.light,
              onSelected: (_) => state.updateSettings(
                state.settings.copyWith(themeMode: ThemeMode.light),
              ),
            ),
            ChoiceChip(
              label: Text(state.t('settings.dark')),
              selected: state.settings.themeMode == ThemeMode.dark,
              onSelected: (_) => state.updateSettings(
                state.settings.copyWith(themeMode: ThemeMode.dark),
              ),
            ),
            ChoiceChip(
              label: Text(state.t('settings.system')),
              selected: state.settings.themeMode == ThemeMode.system,
              onSelected: (_) => state.updateSettings(
                state.settings.copyWith(themeMode: ThemeMode.system),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FontSizeSelector extends StatelessWidget {
  const _FontSizeSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.t('settings.fontSize')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(state.t('settings.small')),
              selected: state.settings.fontScale == 0.9,
              onSelected: (_) =>
                  state.updateSettings(state.settings.copyWith(fontScale: 0.9)),
            ),
            ChoiceChip(
              label: Text(state.t('settings.medium')),
              selected: state.settings.fontScale == 1.0,
              onSelected: (_) =>
                  state.updateSettings(state.settings.copyWith(fontScale: 1)),
            ),
            ChoiceChip(
              label: Text(state.t('settings.large')),
              selected: state.settings.fontScale == 1.1,
              onSelected: (_) =>
                  state.updateSettings(state.settings.copyWith(fontScale: 1.1)),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(state.t('history.empty')),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: state.history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.history[index];
        return ListTile(
          title: Text(
            item.original,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(item.timestamp.toLocal().toString()),
          onTap: () {
            state.loadHistoryItem(item);
            Navigator.of(context).maybePop();
          },
        );
      },
    );
  }
}
