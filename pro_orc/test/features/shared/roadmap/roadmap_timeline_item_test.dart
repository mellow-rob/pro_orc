import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_timeline_view.dart';

void main() {
  final now = DateTime(2026, 6, 1);

  group('RoadmapTimelineItem.fromMilestone — date-shape classification', () {
    test('full start+target, not done, target in future -> onTrack bar', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M1',
          status: 'building',
          start: DateTime(2026, 5, 1),
          target: DateTime(2026, 7, 1),
        ),
        now: now,
      );

      expect(item.shape, TimelineItemShape.bar);
      expect(item.state, TimelineItemState.onTrack);
    });

    test('full start+target, target already passed, not done -> overdue', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M1',
          status: 'building',
          start: DateTime(2026, 1, 1),
          target: DateTime(2026, 2, 1),
        ),
        now: now,
      );

      expect(item.shape, TimelineItemShape.bar);
      expect(item.state, TimelineItemState.overdue);
    });

    test('status done -> finished state regardless of target date', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M1',
          status: 'done',
          start: DateTime(2026, 1, 1),
          target: DateTime(2026, 2, 1),
          finished: DateTime(2026, 1, 20),
        ),
        now: now,
      );

      expect(item.state, TimelineItemState.finished);
      expect(item.shape, TimelineItemShape.bar);
    });

    test('only start date -> point marker at start', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M2',
          status: 'building',
          start: DateTime(2026, 2, 1),
        ),
        now: now,
      );

      expect(item.shape, TimelineItemShape.point);
      expect(item.pointDate, DateTime(2026, 2, 1));
    });

    test('only target date -> point marker at target', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M3',
          status: 'planning',
          target: DateTime(2026, 5, 1),
        ),
        now: now,
      );

      expect(item.shape, TimelineItemShape.point);
      expect(item.pointDate, DateTime(2026, 5, 1));
    });

    test('no dates at all -> shape none (excluded from painted axis)', () {
      final item = RoadmapTimelineItem.fromMilestone(
        const RoadmapMilestone(name: 'M-nodata', status: 'planning'),
        now: now,
      );

      expect(item.shape, TimelineItemShape.none);
    });

    test('finished before start -> dataError, never a backwards bar', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M4',
          status: 'done',
          start: DateTime(2026, 3, 1),
          finished: DateTime(2026, 1, 1),
        ),
        now: now,
      );

      expect(item.state, TimelineItemState.dataError);
      expect(item.shape, isNot(TimelineItemShape.bar));
    });

    test('target before start -> dataError, never a backwards bar', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M5',
          status: 'building',
          start: DateTime(2026, 3, 1),
          target: DateTime(2026, 1, 1),
        ),
        now: now,
      );

      expect(item.state, TimelineItemState.dataError);
      expect(item.shape, isNot(TimelineItemShape.bar));
    });

    test('done item always included, never filtered by status', () {
      final item = RoadmapTimelineItem.fromMilestone(
        RoadmapMilestone(
          name: 'M-done',
          status: 'done',
          start: DateTime(2025, 1, 1),
          finished: DateTime(2025, 2, 1),
        ),
        now: now,
      );

      expect(item.title, 'M-done');
      expect(item.state, TimelineItemState.finished);
    });
  });
}
