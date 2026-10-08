import 'dart:math' as math;

import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/overview/domain/dashboard_stats.dart';
import 'package:flutter/material.dart';

/// Single-series daily bar chart with per-bar hover tooltips.
///
/// One hue (the title names the series, so no legend), 4px rounded tops on a
/// shared baseline, 2px gaps between bars, recessive gridlines, and a hit
/// target spanning the full column height.
class DailyBarChart extends StatefulWidget {
  const DailyBarChart({
    super.key,
    required this.days,
    required this.unit,
    this.height = 180,
  });

  final List<DayCount> days;

  /// Singular noun for tooltips, e.g. "upload" → "16 uploads".
  final String unit;
  final double height;

  @override
  State<DailyBarChart> createState() => _DailyBarChartState();
}

class _DailyBarChartState extends State<DailyBarChart> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = widget.days;
    if (days.isEmpty) return SizedBox(height: widget.height);

    final peak = days.map((d) => d.count).fold(0, math.max);
    final axisMax = _niceCeil(peak);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final gridColor = scheme.outlineVariant.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Y labels: max and midpoint only — enough to read scale.
              SizedBox(
                width: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$axisMax', style: labelStyle),
                    Text('${axisMax ~/ 2}', style: labelStyle),
                    Text('0', style: labelStyle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(gridColor, scheme.outline),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < days.length; i++)
                          Expanded(
                            child: _Bar(
                              day: days[i],
                              fraction:
                                  axisMax == 0 ? 0 : days[i].count / axisMax,
                              unit: widget.unit,
                              hovered: _hovered == i,
                              dimmed: _hovered != null && _hovered != i,
                              color: scheme.primary,
                              hoverColor: scheme.primary.withValues(alpha: 0.08),
                              onHover: (inside) =>
                                  setState(() => _hovered = inside ? i : null),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormatters.shortDate(days.first.day), style: labelStyle),
              Text(
                DateFormatters.shortDate(days[days.length ~/ 2].day),
                style: labelStyle,
              ),
              Text('Today', style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }

  /// Rounds up to 1/2/5 × 10^n so gridlines land on readable numbers.
  static int _niceCeil(int value) {
    if (value <= 4) return 4;
    final magnitude =
        math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
    for (final step in [1, 2, 5, 10]) {
      final candidate = step * magnitude;
      if (candidate >= value && candidate.isEven) return candidate;
    }
    return 10 * magnitude;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.fraction,
    required this.unit,
    required this.hovered,
    required this.dimmed,
    required this.color,
    required this.hoverColor,
    required this.onHover,
  });

  final DayCount day;
  final double fraction;
  final String unit;
  final bool hovered;
  final bool dimmed;
  final Color color;
  final Color hoverColor;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final label = day.count == 1 ? '1 $unit' : '${day.count} ${unit}s';
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Tooltip(
        message: '${DateFormatters.shortDate(day.day)} · $label',
        waitDuration: Duration.zero,
        preferBelow: false,
        child: ColoredBox(
          color: hovered ? hoverColor : Colors.transparent,
          child: Padding(
            // 2px total gap between neighbouring bars.
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction.clamp(0.0, 1.0),
                widthFactor: 1,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: dimmed ? 0.45 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.grid, this.baseline);

  final Color grid;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final y in [0.0, size.height / 2]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.grid != grid || oldDelegate.baseline != baseline;
}
