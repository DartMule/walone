import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g1455/g1455.dart';

import 'storage.dart';
import 'design_system.dart';

class WaloneGlassHost extends StatefulWidget {
  const WaloneGlassHost({
    super.key,
    required this.child,
    this.store,
    this.onThemeModeChanged,
    this.onAccentColorChanged,
  });
  final Widget child;
  final JsonStore? store;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<Color>? onAccentColorChanged;

  static WaloneGlassHostState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppearanceScope>()?.state;

  @override
  State<WaloneGlassHost> createState() => WaloneGlassHostState();
}

class WaloneGlassHostState extends State<WaloneGlassHost>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.soyjanks.walone/appearance');
  bool reduceTransparency = false;
  bool _increaseContrast = false;
  bool _followSystem = true;
  double? _systemTint;
  double? _manualTransparency;
  bool ready = false;
  bool _windowVisible = true;
  bool get windowVisible => _windowVisible;
  bool _liveBackdropNeeded = true;
  bool _capturePolicyScheduled = false;
  bool compactPlayer = true;
  ThemeMode themeMode = ThemeMode.system;
  Color _manualAccentColor = WaloneDesign.defaultAccent;
  Color? _systemAccentColor;
  bool useSystemAccentColor = true;
  Color get accentColor => useSystemAccentColor
      ? _systemAccentColor ?? WaloneDesign.defaultAccent
      : _manualAccentColor;
  String? error;
  Timer? _poll;
  Timer? _saveTimer;
  Future<void> _saveTail = Future.value();

  bool get increaseContrast => _increaseContrast;
  bool get systemAvailable => _systemTint != null;
  bool get followsSystem => systemAvailable && _followSystem;

  GlassFinish _base(BuildContext context) => GlassFinish.regular(
    appearance: Theme.of(context).brightness,
    backdrop: Theme.of(context).scaffoldBackgroundColor,
  );

  // Прежняя шкала transparency хранит глубину материала без изменения формата настроек.
  double transparency(BuildContext context) => reduceTransparency
      ? 0
      : followsSystem
      ? 1 - _systemTint!
      : _manualTransparency ?? 1 - _base(context).tint.a;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await _refresh();
      if (call.method == 'visibility' && call.arguments is bool) {
        _setWindowVisible(call.arguments as bool);
      }
    });
    _initialize();
    _startPolling();
  }

  Future<void> _initialize() async {
    try {
      final saved = await widget.store?.read();
      if (!mounted) return;
      if (saved != null) {
        final manual = saved['transparency'];
        final follow = saved['followSystem'];
        final compact = saved['compactPlayer'];
        final mode = saved['themeMode'];
        final accent = saved['accentColor'];
        final systemAccent = saved['useSystemAccentColor'];
        if ((compact != null && compact is! bool) ||
            (systemAccent != null && systemAccent is! bool) ||
            (accent != null &&
                (accent is! int ||
                    accent < 0xFF000000 ||
                    accent > 0xFFFFFFFF)) ||
            (mode != null &&
                !ThemeMode.values.any((value) => value.name == mode)) ||
            follow is! bool ||
            (manual != null &&
                (manual is! num ||
                    !manual.isFinite ||
                    manual < 0 ||
                    manual > 1))) {
          throw const FormatException('Некорректные настройки интерфейса');
        }
        compactPlayer = (compact as bool?) ?? true;
        useSystemAccentColor = (systemAccent as bool?) ?? true;
        _manualAccentColor = accent == null
            ? WaloneDesign.defaultAccent
            : Color(accent as int);
        _followSystem = follow;
        _manualTransparency = (manual as num?)?.toDouble();
        themeMode = ThemeMode.values.firstWhere(
          (value) => value.name == mode,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {
      widget.store?.protect();
      error =
          'Не удалось прочитать настройки интерфейса. Исходный файл сохранён.';
    }
    await _refresh();
    if (mounted) {
      setState(() => ready = true);
      widget.onThemeModeChanged?.call(themeMode);
      widget.onAccentColorChanged?.call(accentColor);
    }
  }

  Future<void> _refresh() async {
    Map<String, dynamic>? settings;
    try {
      settings = await _channel.invokeMapMethod<String, dynamic>(
        'accessibility',
      );
    } on MissingPluginException {
      // На других платформах доступен ручной режим.
    } on PlatformException {
      // Недоступное системное значение не блокирует ручной режим.
    }
    if (!mounted) return;
    if (settings?['windowVisible'] case final bool visible) {
      _setWindowVisible(visible);
    }
    final rawAccent = settings?['accentColor'];
    final systemAccent =
        rawAccent is int && rawAccent >= 0xFF000000 && rawAccent <= 0xFFFFFFFF
        ? Color(rawAccent)
        : _systemAccentColor;
    final tint = settings?['glassTint'];
    final validatedTint = tint is num && tint.isFinite && tint >= 0 && tint <= 1
        ? tint.toDouble()
        : null;
    final reduce = settings == null
        ? reduceTransparency
        : settings['reduceTransparency'] == true;
    final contrast = settings == null
        ? _increaseContrast
        : settings['increaseContrast'] == true;
    if (_systemAccentColor == systemAccent &&
        _systemTint == validatedTint &&
        reduceTransparency == reduce &&
        _increaseContrast == contrast) {
      return;
    }
    final previousAccent = accentColor;
    setState(() {
      _systemAccentColor = systemAccent;
      _systemTint = validatedTint;
      reduceTransparency = reduce;
      _increaseContrast = contrast;
    });
    if (ready && accentColor != previousAccent) {
      widget.onAccentColorChanged?.call(accentColor);
    }
  }

  void _setWindowVisible(bool visible) {
    if (!mounted || _windowVisible == visible) return;
    setState(() => _windowVisible = visible);
    _poll?.cancel();
    if (visible) {
      _startPolling();
    } else {
      _flushSave();
    }
  }

  void _startPolling() {
    if (!_windowVisible) return;
    // У приватного ключа нет подтверждённого уведомления об изменении.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _poll?.cancel();
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startPolling();
    } else {
      _flushSave();
    }
  }

  void setLiveBackdropNeeded(bool value) {
    if (_liveBackdropNeeded == value) return;
    _liveBackdropNeeded = value;
    if (_capturePolicyScheduled) return;
    _capturePolicyScheduled = true;
    // LayoutBuilder сообщает режим после раскладки; хост обновляем следующим кадром.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePolicyScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void setCompactPlayer(bool value) {
    if (!ready) return;
    setState(() => compactPlayer = value);
    _scheduleSave();
  }

  void setThemeMode(ThemeMode value) {
    if (!ready || themeMode == value) return;
    setState(() => themeMode = value);
    widget.onThemeModeChanged?.call(value);
    _scheduleSave();
  }

  void followSystem(bool value) {
    setState(() => _followSystem = value);
    _scheduleSave();
  }

  void setUseSystemAccentColor(bool value) {
    if (!ready || useSystemAccentColor == value) return;
    setState(() => useSystemAccentColor = value);
    widget.onAccentColorChanged?.call(accentColor);
    _scheduleSave();
  }

  void setAccentColor(Color value) {
    final opaque = value.withValues(alpha: 1);
    if (!ready || useSystemAccentColor || _manualAccentColor == opaque) return;
    setState(() => _manualAccentColor = opaque);
    widget.onAccentColorChanged?.call(accentColor);
    _scheduleSave();
  }

  void setTransparency(double value) {
    if (!ready || followsSystem || reduceTransparency || !value.isFinite) {
      return;
    }
    setState(() => _manualTransparency = value.clamp(0, 1));
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 200), _flushSave);
  }

  void _flushSave() {
    if (_saveTimer == null) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    final saved = {
      'followSystem': _followSystem,
      'compactPlayer': compactPlayer,
      'transparency': _manualTransparency,
      'themeMode': themeMode.name,
      'accentColor': _manualAccentColor.toARGB32(),
      'useSystemAccentColor': useSystemAccentColor,
    };
    _saveTail = _saveTail.then((_) async {
      try {
        await widget.store?.write(saved);
        if (mounted && error != null) setState(() => error = null);
      } catch (_) {
        if (mounted) {
          setState(() => error = 'Не удалось сохранить настройки интерфейса.');
        }
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _flushSave();
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _base(context);
    final value = transparency(context);
    return _AppearanceScope(
      state: this,
      child: GlassHost(
        backdrop: Theme.of(context).scaffoldBackgroundColor,
        // Панели GlassSurface используют общий захват фона этого хоста.
        richBackdrop: false,
        // Смена лимита освобождает pipeline g1455, включая захваченные текстуры.
        maxCaptures: _windowVisible && _liveBackdropNeeded ? null : 0,
        minLabelContrast: kTextContrastAA,
        highContrast: _increaseContrast || MediaQuery.highContrastOf(context),
        tier: GlassTierPolicy(
          reduceTransparency: reduceTransparency || value == 0,
        ).choose(),
        // Тонирование меняет отрисовку поверхностей, но не захват фона.
        // Смена finish у GlassHost пересоздаёт pipeline и временно убирает стекло.
        child: Builder(
          builder: (context) => GlassTheme(
            data: GlassTheme.of(context).copyWith(
              finish: base.copyWith(
                tint: base.tint.withValues(alpha: 1 - value),
                rim: base.rim.withValues(alpha: (base.rim.a + 0.18) * value),
              ),
            ),
            child: TickerMode(
              enabled: _windowVisible,
              child: Offstage(offstage: !_windowVisible, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceScope extends InheritedWidget {
  const _AppearanceScope({required this.state, required super.child});
  final WaloneGlassHostState state;
  @override
  bool updateShouldNotify(_AppearanceScope oldWidget) => true;
}
