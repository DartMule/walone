import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/widgets.dart';
import 'core/storage.dart';

import 'features/keyboard/data/native_keyboard_repository.dart';
import 'features/keyboard/data/keyboard_history_repository.dart';
import 'features/keyboard/data/keyboard_preview.dart';
import 'features/keyboard/domain/keyboard.dart';
import 'features/keyboard/presentation/keyboard_cubit.dart';
import 'features/keyboard/presentation/keyboard_page.dart';
import 'workspace.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (runWebViewTitleBarWidget(arguments)) return;
  final directory = await JsonStore.applicationDirectory();
  runApp(
    WaloneApp(
      appearanceStore: JsonStore(File('${directory.path}/appearance.json')),
    ),
  );
}

class WaloneApp extends StatefulWidget {
  const WaloneApp({
    super.key,
    this.repository = const NativeKeyboardRepository(),
    this.keyboardOnly = false,
    this.historyRepository,
    this.preview,
    this.appearanceStore,
  });

  final KeyboardRepository repository;
  final bool keyboardOnly;
  final KeyboardHistoryRepository? historyRepository;
  final KeyboardPreview? preview;
  final JsonStore? appearanceStore;

  @override
  State<WaloneApp> createState() => _WaloneAppState();
}

class _WaloneAppState extends State<WaloneApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = WaloneDesign.defaultAccent;

  void _setAccentColor(Color value) {
    if (_accentColor != value) setState(() => _accentColor = value);
  }

  void _setThemeMode(ThemeMode value) {
    if (_themeMode != value) setState(() => _themeMode = value);
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => KeyboardCubit(
      widget.repository,
      historyRepository:
          widget.historyRepository ??
          (widget.keyboardOnly ? null : KeyboardHistoryRepository()),
      preview: widget.preview,
    )..initialize(),
    child: MaterialApp(
      title: 'Walone',
      builder: (context, child) => WaloneGlassHost(
        store: widget.appearanceStore,
        onThemeModeChanged: _setThemeMode,
        onAccentColorChanged: _setAccentColor,
        child: child!,
      ),
      debugShowCheckedModeBanner: false,
      theme: WaloneDesign.theme(Brightness.light, accentColor: _accentColor),
      darkTheme: WaloneDesign.theme(Brightness.dark, accentColor: _accentColor),
      themeMode: _themeMode,
      home: widget.keyboardOnly ? const KeyboardPage() : const WorkspaceHost(),
    ),
  );
}
