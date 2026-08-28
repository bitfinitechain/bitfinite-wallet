/*
 * A 7-day price sparkline, drawn from the series CoinGecko already returns
 * alongside the price. Hand-painted rather than pulling in a charting package:
 * one line and one fill needs no dependency, and a package would bring axes,
 * legends and tooltips this has no room for.
 *
 * Renders nothing when there is no series. BFX has no market, so it has no
 * series, and an empty chart frame would read as broken rather than as "not
 * applicable".
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

class PriceSparkline extends StatelessWidget {
  const PriceSparkline({
    super.key,
    required this.series,
    required this.color,
    this.height = 34,
    this.strokeWidth = 2,
  });

  /// Oldest point first. Fewer than two points cannot describe a change, so
  /// nothing is drawn.
  final List<double> series;
  final Color color;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          series: series,
          color: color,
          strokeWidth: strokeWidth,
        ),
        // The series is the whole content, so state it for anyone not looking
        // at the screen. The number beside the chart carries the precise value;
        // this only has to say which way it went.
        child: Semantics(
          label: series.last >= series.first
              ? "Price chart, up over the last seven days"
              : "Price chart, down over the last seven days",
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.series,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> series;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    double lo = series.first, hi = series.first;
    for (final v in series) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }

    // A flat series has zero range. Dividing by it yields NaN and paints
    // nothing at all, so pin it to the middle instead — "no change" is a real
    // answer and should look like one.
    final range = hi - lo;
    final usable = size.height - strokeWidth;
    double y(double v) => range == 0
        ? size.height / 2
        : (strokeWidth / 2) + usable - ((v - lo) / range) * usable;

    final dx = size.width / (series.length - 1);
    final path = Path()..moveTo(0, y(series.first));
    for (var i = 1; i < series.length; i++) {
      path.lineTo(dx * i, y(series[i]));
    }

    // Fill under the line first so the stroke sits on top of its own edge.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The most recent point, marked. Without it the line just stops, and which
    // end is "now" is not obvious.
    canvas.drawCircle(
      Offset(size.width, y(series.last)),
      strokeWidth * 1.4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      !identical(old.series, series);
}
