import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g1455/g1455.dart';

import 'design_system.dart';

export 'appearance.dart';
export 'design_system.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: WaloneDesign.cardRadius,
    child: Padding(
      padding: const EdgeInsets.all(WaloneDesign.cardPadding),
      child: child,
    ),
  );
}

/// Карточки используют тот же матовый материал, что навигация и плеер.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = WaloneDesign.cardRadius,
    this.selected = false,
  });
  final Widget child;
  final double radius;
  final bool selected;

  @override
  Widget build(BuildContext context) =>
      FrostedPanel(radius: radius, selected: selected, child: child);
}

/// Общий матовый материал панелей, навигации и плеера.
/// GlassSurface использует общий захват GlassHost, сохраняя содержимое чётким.
class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.radius = WaloneDesign.playerRadius,
    this.sidebar = false,
    this.selected = false,
  });

  final Widget child;
  final double radius;
  final bool sidebar;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = GlassTheme.of(context);
    final strength = glass.tier.tier == GlassTier.opaque || glass.highContrast
        ? 0.0
        : (1 - glass.finish.tint.a).clamp(0.0, 1.0);
    final dark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final baseFill = sidebar
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.surface;
    // На ровном тёмном фоне размытие и чёрная тень почти незаметны.
    // Светлота поверхности делает глубину различимой и без пёстрого фона.
    final fill = dark
        ? Color.lerp(
            baseFill,
            sidebar
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHigh,
            strength,
          )!
        : baseFill;
    // Плотное тонирование сохраняет контраст подписей поверх любого контента.
    final opacity = 1 - (dark ? 0.04 : 0.06) * strength;
    final material = Material(
      color: fill.withValues(alpha: opacity),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : glass.highContrast
              ? theme.colorScheme.outline
              : Colors.white.withValues(alpha: (dark ? 0.30 : 0.75) * strength),
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: strength == 0
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: (dark ? 0.24 : 0.10) * strength,
                  ),
                  blurRadius: sidebar ? 16 : 24,
                  offset: sidebar ? const Offset(3, 0) : const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: strength == 0
            ? material
            : GlassSurface(
                borderRadius: borderRadius,
                // Тонирование и кромку рисует Material; повторять их не нужно.
                labelled: false,
                finish: glass.finish.copyWith(
                  blurSigmaLogical: 20 * strength,
                  tint: Colors.transparent,
                  rim: Colors.transparent,
                ),
                child: material,
              ),
      ),
    );
  }
}

/// Компактный пункт настольного меню с общей геометрией и цветами темы.
class DesktopMenuItem<T> extends PopupMenuItem<T> {
  DesktopMenuItem({
    super.key,
    required super.value,
    required String label,
    IconData? icon,
    bool destructive = false,
    bool selected = false,
  }) : super(
         height: 34,
         padding: const EdgeInsets.symmetric(horizontal: 10),
         child: _DesktopMenuLabel(
           label: label,
           icon: icon,
           destructive: destructive,
           selected: selected,
         ),
       );
}

class _DesktopMenuLabel extends StatelessWidget {
  const _DesktopMenuLabel({
    required this.label,
    this.icon,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 16),
          Icon(Icons.check_rounded, size: 14, color: color),
        ],
      ],
    );
  }
}

class DesktopSelect<T> extends StatefulWidget {
  const DesktopSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.label,
  });

  final T? value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;
  final String hint;
  final String? label;

  @override
  State<DesktopSelect<T>> createState() => _DesktopSelectState<T>();
}

class _DesktopSelectState<T> extends State<DesktopSelect<T>> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.onChanged != null;
    final foreground = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final control = Focus(
      canRequestFocus: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: PopupMenuButton<T>(
          tooltip: widget.hint,
          enabled: enabled,
          initialValue: widget.value,
          requestFocus: true,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 5),
          borderRadius: BorderRadius.circular(WaloneDesign.controlRadius),
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
          itemBuilder: (_) => [
            for (final entry in widget.items.entries)
              DesktopMenuItem(
                value: entry.key,
                label: entry.value,
                selected: entry.key == widget.value,
              ),
          ],
          onSelected: widget.onChanged,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: WaloneDesign.controlHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: enabled && _hovered
                  ? scheme.surfaceContainerHigh
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(WaloneDesign.controlRadius),
              border: Border.all(
                color: enabled && _focused
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: 0.5,
              ),
              boxShadow: enabled && _focused
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.20),
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.items[widget.value] ?? widget.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.unfold_more_rounded, size: 14, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: control,
    );
    if (widget.label == null) return button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        button,
      ],
    );
  }
}

class SceneBanner extends StatelessWidget {
  const SceneBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: WaloneDesign.cardRadius,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WaloneDesign.cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
          if (action == null) return heading;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), action!],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              action!,
            ],
          );
        },
      ),
    ),
  );
}

class GainSlider extends StatefulWidget {
  const GainSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Громкость',
    this.max = 1,
    this.live = false,
    this.compact = false,
    this.showValue = true,
  });
  final double value;
  final double max;
  final bool live;
  final bool compact;
  final bool showValue;
  final String label;
  final ValueChanged<double>? onChanged;
  @override
  State<GainSlider> createState() => _GainSliderState();
}

class _GainSliderState extends State<GainSlider> {
  double? _drag;
  bool _dragging = false;
  bool _trackDragging = false;
  bool _focused = false;
  final _focus = FocusNode();

  double get _maximum => widget.max > 0 ? widget.max : 1;
  double get _value => (_drag ?? widget.value).clamp(0, _maximum);

  double _position(double x, double width) {
    final fraction = (x / width).clamp(0.0, 1.0);
    return _maximum *
        (Directionality.of(context) == TextDirection.rtl
            ? 1 - fraction
            : fraction);
  }

  void _change(double value) {
    setState(() => _drag = value);
    if (!_dragging || widget.live) widget.onChanged?.call(value);
  }

  void _finish(double value) {
    setState(() {
      _dragging = false;
      _trackDragging = false;
      _drag = value;
    });
    widget.onChanged?.call(value);
  }

  @override
  void didUpdateWidget(GainSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Звук и сохранение могут завершиться позже жеста. Старое значение при
    // посторонней перерисовке ещё не является подтверждением нового уровня.
    if (!_dragging &&
        (widget.value != oldWidget.value ||
            widget.max != oldWidget.max ||
            widget.onChanged == null)) {
      _drag = null;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (widget.onChanged == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final reverse = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => reverse,
      LogicalKeyboardKey.arrowLeft => -reverse,
      LogicalKeyboardKey.arrowUp => 1,
      LogicalKeyboardKey.arrowDown => -1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;
    _change((_value + direction * _maximum * 0.05).clamp(0, _maximum));
    return KeyEventResult.handled;
  }

  Widget _control() => CupertinoSlider(
    value: _value,
    max: _maximum,
    activeColor: Theme.of(context).colorScheme.primary,
    onChanged: widget.onChanged == null ? null : _change,
    onChangeStart: (_) {
      _dragging = true;
      _focus.requestFocus();
    },
    onChangeEnd: _finish,
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TapRegion(
          onTapOutside: (_) => _focus.unfocus(),
          child: Focus(
            focusNode: _focus,
            canRequestFocus: widget.onChanged != null,
            onFocusChange: (value) => setState(() => _focused = value),
            onKeyEvent: _key,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _focused
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                ),
              ),
              // Material Slider в Flutter 3.44 создаёт осиротевший AX-узел через
              // OverlayPortal. Cupertino сохраняет доступность без этого портала.
              child: MergeSemantics(
                child: Semantics(
                  label: widget.label,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onHorizontalDragStart: widget.onChanged == null
                          ? null
                          : (_) {
                              _dragging = true;
                              _trackDragging = true;
                              _focus.requestFocus();
                            },
                      onHorizontalDragUpdate: widget.onChanged == null
                          ? null
                          : (details) {
                              _change(
                                _position(
                                  details.localPosition.dx,
                                  constraints.maxWidth,
                                ),
                              );
                            },
                      onHorizontalDragEnd: widget.onChanged == null
                          ? null
                          : (_) => _finish(_value),
                      onHorizontalDragCancel: widget.onChanged == null
                          ? null
                          : () {
                              if (_trackDragging) _finish(_value);
                            },
                      onTapUp: widget.onChanged == null
                          ? null
                          : (details) {
                              _focus.requestFocus();
                              _change(
                                _position(
                                  details.localPosition.dx,
                                  constraints.maxWidth,
                                ),
                              );
                            },
                      child: widget.compact
                          ? SizedBox(
                              height: 26,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: constraints.maxWidth / 0.6,
                                  height: 44,
                                  child: _control(),
                                ),
                              ),
                            )
                          : _control(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (widget.max == 1 && widget.showValue)
        SizedBox(
          width: widget.compact ? 32 : 42,
          child: Text(
            '${((_drag ?? widget.value) * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: widget.compact ? 10 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
    ],
  );
}

/// Общая оболочка настольных диалогов: матовый материал и компактная типографика.
class WaloneDialog extends StatelessWidget {
  const WaloneDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = GlassTheme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassProxy.hidden(
        child: GlassTheme(
          data: glass.copyWith(
            tier: glass.tier.tier == GlassTier.opaque
                ? glass.tier
                : const GlassTierPolicy(pinned: GlassTier.cheap).choose(),
          ),
          child: FrostedPanel(
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Semantics(
                        namesRoute: true,
                        header: true,
                        child: DefaultTextStyle(
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontSize: 17,
                          ),
                          child: title,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: DefaultTextStyle(
                          style: theme.textTheme.bodyMedium!,
                          child: content,
                        ),
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 8,
                        overflowSpacing: 8,
                        overflowAlignment: OverflowBarAlignment.end,
                        children: actions,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NameDialog extends StatefulWidget {
  const NameDialog({super.key, required this.title, this.initial = ''});
  final String title;
  final String initial;
  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WaloneDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 400,
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Название'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
        },
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Сохранить'),
      ),
    ],
  );
}

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => WaloneDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Отмена'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Удалить'),
      ),
    ],
  );
}

String timeLabel(double seconds) {
  final value = seconds.isFinite ? seconds.floor().clamp(0, 8640000) : 0;
  final hours = value ~/ 3600;
  final minutes = (value ~/ 60) % 60;
  return '${hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}' : '${value ~/ 60}'}:${(value % 60).toString().padLeft(2, '0')}';
}
