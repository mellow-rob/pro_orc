import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Shape a single [RoadmapTimelineItem] is painted with on the time axis.
///
/// - [bar] — both a start and a target (or finished) date are known, so a
///   horizontal span can be drawn (FR-015).
/// - [point] — only ONE of start/target is known: a single point marker is
///   drawn at that date instead of a bar (FR-025 — never invent the missing
///   end of the span).
/// - [none] — no date at all; the item is still listed (FR-024) but has
///   nothing to paint on the axis.
enum TimelineItemShape { bar, point, none }

/// Visual/semantic state of a timeline item, independent of [TimelineItemShape].
///
/// [dataError] always wins over the date-derived overdue/onTrack states —
/// an inconsistent date pair (e.g. `finished` before `start`) must never be
/// rendered as a literal (potentially backwards) bar (FR-026).
enum TimelineItemState { finished, overdue, onTrack, dataError }

/// Source-agnostic timeline row: either a [RoadmapMilestone] or a
/// [RoadmapPhase] (a "feature" in spec language), flattened into one shape
/// the painter/legend can reason about without knowing which model it came
/// from.
///
/// Deliberately NOT wrapping `RoadmapMilestone`/`RoadmapPhase` directly so
/// the painter has one uniform shape to render regardless of nesting depth,
/// per the Wave 6 brief's "reuse existing models, wrap only if needed"
/// guidance.
@immutable
class RoadmapTimelineItem {
  const RoadmapTimelineItem({
    required this.title,
    required this.rawStatus,
    required this.start,
    required this.target,
    required this.finished,
    required this.depth,
    required this.shape,
    required this.state,
    required this.pointDate,
  });

  /// Display title (milestone or phase name).
  final String title;

  /// Raw/normalized status string, unused for now beyond `done` detection —
  /// kept so future callers (e.g. tooltips) can show it without recomputing.
  final String rawStatus;

  final DateTime? start;
  final DateTime? target;
  final DateTime? finished;

  /// 0 for a milestone row, 1 for a nested phase/feature row — lets the
  /// painter indent nested rows without a second model.
  final int depth;

  final TimelineItemShape shape;
  final TimelineItemState state;

  /// The single date to paint a point marker at when [shape] is
  /// [TimelineItemShape.point]. Null otherwise.
  final DateTime? pointDate;

  static bool _isDone(String rawStatus) =>
      rawStatus.toLowerCase().contains(RegExp('done|complete|finish|shipped'));

  /// Builds a [RoadmapTimelineItem] from a [RoadmapMilestone], classifying
  /// its date shape/state relative to [now].
  factory RoadmapTimelineItem.fromMilestone(
    RoadmapMilestone milestone, {
    required DateTime now,
  }) => _classify(
    title: milestone.name,
    rawStatus: milestone.status,
    start: milestone.start,
    target: milestone.target,
    finished: milestone.finished,
    depth: 0,
    now: now,
  );

  /// Builds a [RoadmapTimelineItem] from a [RoadmapPhase] ("feature" row),
  /// nested one level under its parent milestone.
  factory RoadmapTimelineItem.fromPhase(
    RoadmapPhase phase, {
    required DateTime now,
  }) => _classify(
    title: phase.name,
    rawStatus: phase.status,
    start: phase.start,
    target: phase.target,
    finished: phase.finished,
    depth: 1,
    now: now,
  );

  static RoadmapTimelineItem _classify({
    required String title,
    required String rawStatus,
    required DateTime? start,
    required DateTime? target,
    required DateTime? finished,
    required int depth,
    required DateTime now,
  }) {
    final isDone = _isDone(rawStatus);

    // FR-026: inconsistent dates (finished/target before start) are ALWAYS
    // a data-error, regardless of shape or done-status — checked first so
    // no other branch can mask it.
    final hasInconsistency =
        (start != null && finished != null && finished.isBefore(start)) ||
        (start != null && target != null && target.isBefore(start));

    if (hasInconsistency) {
      return RoadmapTimelineItem(
        title: title,
        rawStatus: rawStatus,
        start: start,
        target: target,
        finished: finished,
        depth: depth,
        shape: TimelineItemShape.none,
        state: TimelineItemState.dataError,
        pointDate: null,
      );
    }

    // FR-025: exactly one of start/target present -> single point marker.
    final hasStart = start != null;
    final hasTarget = target != null;
    if (hasStart != hasTarget && finished == null) {
      return RoadmapTimelineItem(
        title: title,
        rawStatus: rawStatus,
        start: start,
        target: target,
        finished: finished,
        depth: depth,
        shape: TimelineItemShape.point,
        state: isDone ? TimelineItemState.finished : TimelineItemState.onTrack,
        pointDate: start ?? target,
      );
    }

    // No dates at all -> nothing to paint, but the item is still listed
    // (FR-024).
    if (start == null && target == null && finished == null) {
      return RoadmapTimelineItem(
        title: title,
        rawStatus: rawStatus,
        start: null,
        target: null,
        finished: null,
        depth: depth,
        shape: TimelineItemShape.none,
        state: isDone ? TimelineItemState.finished : TimelineItemState.onTrack,
        pointDate: null,
      );
    }

    // Full (or start+finished) pair -> a bar. State: finished wins if the
    // item is done; otherwise overdue iff the target date has passed.
    final state = isDone
        ? TimelineItemState.finished
        : (target != null && target.isBefore(now))
        ? TimelineItemState.overdue
        : TimelineItemState.onTrack;

    return RoadmapTimelineItem(
      title: title,
      rawStatus: rawStatus,
      start: start,
      target: target,
      finished: finished,
      depth: depth,
      shape: TimelineItemShape.bar,
      state: state,
      pointDate: null,
    );
  }
}

/// Flattens a milestone list (with nested phases) into painter-ready rows,
/// in stable display order: each milestone row immediately followed by its
/// phase rows.
List<RoadmapTimelineItem> _buildItems(
  List<RoadmapMilestone> milestones,
  DateTime now,
) {
  final items = <RoadmapTimelineItem>[];
  for (final milestone in milestones) {
    items.add(RoadmapTimelineItem.fromMilestone(milestone, now: now));
    for (final phase in milestone.phases) {
      items.add(RoadmapTimelineItem.fromPhase(phase, now: now));
    }
  }
  return items;
}

/// Timeline/Gantt view of milestones + features (FR-015).
///
/// Standalone widget — intentionally NOT wired into `roadmap_tab.dart` yet
/// (that happens in Wave 7 via the view toggle). Custom-painted, no new
/// package dependency (per the Wave 3 dependency decision), full dark-theme
/// control via [AppColors].
///
/// Renders ALL items regardless of status, including already-`done` ones
/// (FR-024). Items with only a start OR only a target date render as a
/// single point marker, never a bar (FR-025). Items with internally
/// inconsistent dates (e.g. `finished` before `start`) are flagged with a
/// warning marker/color, never as a literal backwards bar (FR-026).
/// Overdue/on-track/finished items use distinct colors so all three are
/// distinguishable in one glance (SC-005).
class RoadmapTimelineView extends StatelessWidget {
  const RoadmapTimelineView({super.key, required this.milestones, this.now});

  /// Milestones (with nested phases/features) to render on the timeline.
  final List<RoadmapMilestone> milestones;

  /// Reference "today" used to classify overdue vs. on-track. Defaults to
  /// [DateTime.now] — overridable for deterministic widget tests.
  final DateTime? now;

  static const double _rowHeight = 40;
  static const double _labelWidth = 230;
  static const double _legendHeight = 40;
  static const double _axisPadding = 24;
  static const double _monthAxisHeight = 22;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final effectiveNow = now ?? DateTime.now();
    final items = _buildItems(milestones, effectiveNow);

    // "Usable for the axis" means the item has ANY date to plot, whether
    // painted as a bar/point (shape != none) or as an error marker at the
    // label column (shape == none but state == dataError, e.g. finished <
    // start with no target). Only items with genuinely zero dates are
    // excluded from range computation.
    final plottableItems = items
        .where(
          (i) =>
              i.shape != TimelineItemShape.none ||
              i.state == TimelineItemState.dataError,
        )
        .toList();

    if (plottableItems.isEmpty) {
      return _TimelineEmptyState(colors: colors);
    }

    final range = _dateRange(plottableItems);
    // The "heute" line (mockup `.tl-today`) is only drawn when `now` falls
    // inside the plotted range — outside it the line would sit off-canvas
    // or overlap the axis, so it is simply omitted rather than clamped.
    final showTodayLine =
        !effectiveNow.isBefore(range.start) && !effectiveNow.isAfter(range.end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TimelineLegend(colors: colors, height: _legendHeight),
        const SizedBox(height: 8),
        GlassCard(
          child: Padding(
            // Mockup v2 `.timeline { padding: 22px; }` (FR-005 density pass).
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              height:
                  items.length * _rowHeight + _axisPadding + _monthAxisHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TimelinePainter(
                            items: items,
                            range: range,
                            colors: colors,
                            labelWidth: _labelWidth,
                            rowHeight: _rowHeight,
                            axisPadding: _axisPadding,
                            monthAxisHeight: _monthAxisHeight,
                            now: effectiveNow,
                            showTodayLine: showTodayLine,
                          ),
                        ),
                      ),
                      for (var i = 0; i < items.length; i++)
                        Positioned(
                          left: 8 + items[i].depth * 16,
                          top: i * _rowHeight,
                          width: _labelWidth - 16,
                          height: _rowHeight,
                          child: _TimelineRowLabel(
                            item: items[i],
                            colors: colors,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  static ({DateTime start, DateTime end}) _dateRange(
    List<RoadmapTimelineItem> items,
  ) {
    final dates = <DateTime>[];
    for (final item in items) {
      if (item.start != null) dates.add(item.start!);
      if (item.target != null) dates.add(item.target!);
      if (item.finished != null) dates.add(item.finished!);
      if (item.pointDate != null) dates.add(item.pointDate!);
    }
    var start = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    var end = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    if (start == end) {
      // Guarantee a non-zero span so the painter has room to place a marker.
      start = start.subtract(const Duration(days: 7));
      end = end.add(const Duration(days: 7));
    }
    return (start: start, end: end);
  }
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Keine Termine hinterlegt — Start-, Ziel- oder Fertigstellungsdatum '
          'fehlen für alle Einträge.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textDim, fontSize: 13),
        ),
      ),
    );
  }
}

class _TimelineLegend extends StatelessWidget {
  const _TimelineLegend({required this.colors, required this.height});

  final AppColors colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LegendEntry(
            color: _stateColor(TimelineItemState.finished, colors),
            label: 'Fertig',
          ),
          _LegendEntry(
            color: _stateColor(TimelineItemState.onTrack, colors),
            label: 'Aktiv',
          ),
          _LegendEntry(
            color: _stateColor(TimelineItemState.overdue, colors),
            label: 'Überfällig',
          ),
          // Mockup "Einzeltermin" entry (rotated-square swatch) — the
          // point-marker shape used when only start OR target is known
          // (FR-025); colored like an on-track item since a lone point has
          // no separate state of its own.
          _LegendEntry(
            color: colors.textDim,
            label: 'Einzeltermin',
            rotated: true,
          ),
          _LegendEntry(
            color: _stateColor(TimelineItemState.dataError, colors),
            label: 'Datenfehler',
            icon: Icons.warning_amber_rounded,
          ),
          _LegendEntry(color: colors.fuch, label: 'Heute'),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    this.icon,
    this.rotated = false,
  });

  final Color color;
  final String label;
  final IconData? icon;

  /// Mockup `#zeitstrahl .tl-legend i` rotates the swatch 45deg for the
  /// "Einzeltermin" (point-marker) legend entry to mirror the rotated-square
  /// point markers drawn on the timeline itself.
  final bool rotated;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 14)
          else
            Transform.rotate(
              angle: rotated ? 0.785398 : 0, // 45deg
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(rotated ? 2 : 3),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TimelineRowLabel extends StatelessWidget {
  const _TimelineRowLabel({required this.item, required this.colors});

  final RoadmapTimelineItem item;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final isError = item.state == TimelineItemState.dataError;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isError)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.warning_amber_rounded,
              color: _stateColor(TimelineItemState.dataError, colors),
              size: 14,
              semanticLabel: 'Datenfehler bei den Terminen',
            ),
          ),
        Flexible(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: item.depth == 0 ? colors.textPri : colors.textSec,
              fontSize: item.depth == 0 ? 13 : 12,
              fontWeight: item.depth == 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Maps a [TimelineItemState] to its display color — the single source of
/// truth for SC-005's "distinct visual treatment per state" requirement.
Color _stateColor(TimelineItemState state, AppColors colors) {
  return switch (state) {
    TimelineItemState.finished => colors.emerald,
    TimelineItemState.overdue => const Color(0xFFEF4444),
    TimelineItemState.onTrack => colors.cyan,
    TimelineItemState.dataError => colors.amber,
  };
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.items,
    required this.range,
    required this.colors,
    required this.labelWidth,
    required this.rowHeight,
    required this.axisPadding,
    required this.monthAxisHeight,
    required this.now,
    required this.showTodayLine,
  });

  final List<RoadmapTimelineItem> items;
  final ({DateTime start, DateTime end}) range;
  final AppColors colors;
  final double labelWidth;
  final double rowHeight;
  final double axisPadding;
  final double monthAxisHeight;
  final DateTime now;
  final bool showTodayLine;

  double get _tracksHeight => items.length * rowHeight;

  double _xFor(DateTime date, double axisWidth) {
    final totalSpan = range.end.difference(range.start).inMilliseconds;
    if (totalSpan <= 0) return labelWidth;
    final offset = date.difference(range.start).inMilliseconds;
    final fraction = (offset / totalSpan).clamp(0.0, 1.0);
    return labelWidth + fraction * axisWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final axisWidth = (size.width - labelWidth).clamp(0.0, double.infinity);
    final tracksHeight = _tracksHeight;

    // Baseline axis line, mockup `.tl-track` track background per row.
    final trackPaint = Paint()..color = colors.textPri.withValues(alpha: 0.03);
    for (var i = 0; i < items.length; i++) {
      final rowTop = i * rowHeight + 4;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelWidth, rowTop, axisWidth, rowHeight - 8),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, trackPaint);
    }

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final rowCenterY = i * rowHeight + rowHeight / 2;
      final color = _stateColor(item.state, colors);

      switch (item.shape) {
        case TimelineItemShape.bar:
          _paintBar(canvas, item, rowCenterY, axisWidth, color);
        case TimelineItemShape.point:
          _paintPoint(canvas, item, rowCenterY, axisWidth, color);
        case TimelineItemShape.none:
          if (item.state == TimelineItemState.dataError) {
            _paintErrorMarkerAtLabel(canvas, rowCenterY, color);
          }
      }
    }

    // Mockup `.tl-today` — a single magenta line spanning the full track
    // height (not one line per row), drawn on top of the tracks/bars.
    if (showTodayLine) {
      final x = _xFor(now, axisWidth);
      final todayPaint = Paint()
        ..color = colors.fuch
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, -6), Offset(x, tracksHeight + 6), todayPaint);
    }

    _paintMonthAxis(canvas, axisWidth, tracksHeight);
  }

  void _paintBar(
    Canvas canvas,
    RoadmapTimelineItem item,
    double rowCenterY,
    double axisWidth,
    Color color,
  ) {
    // A bar requires a start; the end is target if present, else finished.
    final start = item.start;
    final end = item.target ?? item.finished;
    if (start == null || end == null) return;

    final x1 = _xFor(start, axisWidth);
    final x2Raw = _xFor(end, axisWidth);
    final x2 = x2Raw < x1 + 4 ? x1 + 4 : x2Raw;
    const barHeight = 10.0;

    // Mockup `.tl-bar.done`/`.tl-bar.active` — a horizontal gradient from
    // the full-strength state color to a dimmer tail, not a flat fill.
    final rect = Rect.fromLTRB(
      x1,
      rowCenterY - barHeight / 2,
      x2,
      rowCenterY + barHeight / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          color.withValues(
            alpha: item.state == TimelineItemState.finished ? 0.85 : 1.0,
          ),
          color.withValues(
            alpha: item.state == TimelineItemState.finished ? 0.45 : 0.55,
          ),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      paint,
    );
  }

  void _paintPoint(
    Canvas canvas,
    RoadmapTimelineItem item,
    double rowCenterY,
    double axisWidth,
    Color color,
  ) {
    final date = item.pointDate;
    if (date == null) return;
    final x = _xFor(date, axisWidth);

    // Mockup `.tl-point` — a 12x12 square rotated 45deg (a "diamond"), not
    // a circle.
    canvas.save();
    canvas.translate(x, rowCenterY);
    canvas.rotate(0.785398); // 45deg

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const half = 6.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-half, -half, half * 2, half * 2),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.restore();
  }

  void _paintErrorMarkerAtLabel(Canvas canvas, double rowCenterY, Color color) {
    // No usable date at all could still combine with a data-error verdict
    // in theory (defensive) — draw a small warning triangle just right of
    // the label column so it is never silently dropped from the axis.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(labelWidth + 6, rowCenterY - 6)
      ..lineTo(labelWidth + 14, rowCenterY + 6)
      ..lineTo(labelWidth - 2, rowCenterY + 6)
      ..close();
    canvas.drawPath(path, paint);
  }

  /// Mockup `.tl-axis .marks` — evenly spaced month labels below the
  /// tracks, spanning [range.start] to [range.end].
  void _paintMonthAxis(Canvas canvas, double axisWidth, double tracksHeight) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mrz',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    final axisY = tracksHeight + axisPadding / 2;
    const marksCount = 4;
    for (var i = 0; i < marksCount; i++) {
      final t = marksCount == 1 ? 0.0 : i / (marksCount - 1);
      final spanMs = range.end.difference(range.start).inMilliseconds;
      final date = range.start.add(
        Duration(milliseconds: (spanMs * t).round()),
      );
      final label = "${monthNames[date.month - 1]} '${date.year % 100}";
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            color: colors.textDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = labelWidth + t * axisWidth;
      final dx = i == 0
          ? 0.0
          : (i == marksCount - 1 ? -textPainter.width : -textPainter.width / 2);
      textPainter.paint(canvas, Offset(x + dx, axisY));
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.range != range ||
      oldDelegate.now != now ||
      oldDelegate.showTodayLine != showTodayLine;
}
