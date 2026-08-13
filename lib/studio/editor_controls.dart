import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/studio_theme.dart';

class ParameterSlider extends StatelessWidget {
  const ParameterSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueFormatter,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final String Function(double value)? valueFormatter;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final formatter = valueFormatter ?? (value) => value.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(
              formatter(value),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xxs),
        SizedBox(
          height: StudioMetrics.compactControlHeight,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

class NumericValueField extends StatelessWidget {
  const NumericValueField({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.enabled = true,
    this.width = 64,
  });

  final num value;
  final ValueChanged<double> onSubmitted;
  final bool enabled;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: StudioMetrics.compactControlHeight,
      child: TextFormField(
        enabled: enabled,
        initialValue: '$value',
        textAlign: TextAlign.end,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
        ],
        style: Theme.of(context).textTheme.bodySmall,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: StudioSpacing.sm,
            vertical: StudioSpacing.xs,
          ),
          border: OutlineInputBorder(),
        ),
        onFieldSubmitted: (text) {
          final parsed = double.tryParse(text);
          if (parsed != null) onSubmitted(parsed);
        },
      ),
    );
  }
}

class CompactDropdown<T> extends StatelessWidget {
  const CompactDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StudioMetrics.compactControlHeight,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm),
          border: OutlineInputBorder(),
        ),
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class CompactToggle extends StatelessWidget {
  const CompactToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StudioMetrics.compactControlHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StudioMetrics.compactRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
