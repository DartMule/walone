import 'package:flutter/material.dart';

import '../../../core/widgets.dart';

class ThemeColors extends StatelessWidget {
  const ThemeColors({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = WaloneGlassHost.maybeOf(context)!;
    final custom = !WaloneDesign.accentColors.containsValue(
      appearance.accentColor,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Цветовая тема', style: Theme.of(context).textTheme.titleMedium),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Использовать системный цвет'),
          value: appearance.useSystemAccentColor,
          onChanged: appearance.ready
              ? (value) => appearance.setUseSystemAccentColor(value!)
              : null,
        ),
        if (!appearance.useSystemAccentColor) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in WaloneDesign.accentColors.entries)
                Semantics(
                  selected: appearance.accentColor == entry.value,
                  child: Tooltip(
                    message: entry.key,
                    child: IconButton(
                      onPressed: appearance.ready
                          ? () => appearance.setAccentColor(entry.value)
                          : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.all(4),
                        shape: const CircleBorder(),
                      ),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.16),
                          ),
                        ),
                        child: appearance.accentColor == entry.value
                            ? Icon(
                                Icons.check_rounded,
                                size: 22,
                                color:
                                    ThemeData.estimateBrightnessForColor(
                                          entry.value,
                                        ) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              Semantics(
                selected: custom,
                child: TextButton.icon(
                  onPressed: appearance.ready
                      ? () async {
                          final color = await showDialog<Color>(
                            context: context,
                            builder: (_) => _CustomColorDialog(
                              initial: appearance.accentColor,
                            ),
                          );
                          if (color != null && appearance.mounted) {
                            appearance.setAccentColor(color);
                          }
                        }
                      : null,
                  icon: Icon(
                    custom ? Icons.check_circle : Icons.palette_outlined,
                  ),
                  label: const Text('Свой цвет'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Цвет кнопок, выделения и переключателей. Сохраняется автоматически.',
          ),
        ],
      ],
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});
  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: _hexValue(widget.initial));
  bool _valid = true;

  String _hexValue(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  void _update(HSVColor value) {
    setState(() {
      _color = value;
      _valid = true;
      _hex.text = _hexValue(value.toColor());
    });
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = WaloneDesign.theme(
      Theme.of(context).brightness,
      accentColor: _color.toColor(),
    );
    return WaloneDialog(
      title: const Text('Свой цвет'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: preview.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(WaloneDesign.cardRadius),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: preview.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Предпросмотр',
                      style: TextStyle(
                        color: preview.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _color.toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: preview.colorScheme.outline),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Оттенок'),
            Slider(
              semanticFormatterCallback: (value) =>
                  'Оттенок: ${value.round()}°',
              activeColor: HSVColor.fromAHSV(1, _color.hue, 1, 1).toColor(),
              value: _color.hue,
              max: 360,
              onChanged: (value) => _update(_color.withHue(value)),
            ),
            const Text('Насыщенность'),
            Slider(
              semanticFormatterCallback: (value) =>
                  'Насыщенность: ${(value * 100).round()}%',
              value: _color.saturation,
              onChanged: (value) => _update(_color.withSaturation(value)),
            ),
            const Text('Яркость'),
            Slider(
              semanticFormatterCallback: (value) =>
                  'Яркость: ${(value * 100).round()}%',
              value: _color.value,
              onChanged: (value) => _update(_color.withValue(value)),
            ),
            TextField(
              controller: _hex,
              maxLength: 7,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'HEX',
                hintText: '#007AFF',
                errorText: _valid ? null : 'Введите 6 символов: 0–9, A–F',
                helperText: 'Например, #8B65CC',
              ),
              onChanged: (value) {
                final hex = value.trim().replaceFirst(RegExp(r'^#'), '');
                setState(() {
                  _valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex);
                  if (_valid) {
                    _color = HSVColor.fromColor(
                      Color(0xFF000000 | int.parse(hex, radix: 16)),
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(_color.toColor())
              : null,
          child: const Text('Применить'),
        ),
      ],
    );
  }
}
