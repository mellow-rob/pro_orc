import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lanes_view.dart';
import 'package:pro_orc/features/shared/roadmap/offline_fallback_badge.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_hero.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tree.dart';
import 'package:pro_orc/features/shared/roadmap/spec_list.dart';
import 'package:pro_orc/features/shared/roadmap/spec_viewer.dart';
import 'package:pro_orc/features/shared/roadmap/whats_next_indicator.dart';
import 'package:pro_orc/providers/roadmap_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Read-only "Roadmap" tab body: fixed 35/65 split-view (tree left, detail
/// right — no draggable divider, FR-016), fed by [roadmapProvider]'s
/// three-tier fallback resolution.
///
/// Exactly one of three states renders: loading, the empty state (no data
/// from any tier, or a slug that matched nothing — FR-007/FR-008), or the
/// split-view populated with milestones/phases (FR-001/FR-003) plus the
/// offline-fallback badge when the Vault tier resolved the data (FR-010a).
class RoadmapTab extends ConsumerWidget {
  const RoadmapTab({super.key, required this.project, required this.accent});

  final ProjectModel project;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final resultAsync = ref.watch(roadmapProvider(project));

    // Fills all height given by the caller (ProjectDetailPanel wraps this in
    // an Expanded) instead of a fixed height — the full-screen detail view
    // gives the split-view much more vertical room than the old modal did.
    return resultAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 2),
      ),
      // Services never throw, but the provider chain still surfaces
      // errors as an AsyncError if something upstream misbehaves — treat
      // that identically to "no data" rather than showing a raw error
      // (FR-007).
      error: (_, _) => _EmptyRoadmapState(colors: colors),
      data: (result) {
        if (result.data.isEmpty) {
          return _EmptyRoadmapState(colors: colors);
        }
        // Tier-0 (docs/product/) gets the Wave 4 hero + milestone-lane +
        // feature-card view; every other tier keeps the original tree +
        // spec-list split-view (Waves 1-2), unchanged.
        if (result.source == RoadmapSource.productStore) {
          return _RoadmapHeroView(
            data: result.data,
            colors: colors,
            accent: accent,
          );
        }
        return _RoadmapSplitView(
          data: result.data,
          source: result.source,
          colors: colors,
          accent: accent,
          currentPhase: null,
        );
      },
    );
  }
}

/// Tier-0 (docs/product/) Roadmap view (Wave 4): hero ("Wo stehen wir" from
/// NEXT.md) + milestone lanes with click-to-drill-down feature cards.
///
/// Kept as its own top-level widget (not nested inside `_RoadmapSplitView`)
/// so a later `viewMode` toggle (Wave 7, lanes|timeline) can wrap
/// [MilestoneLanesView] without touching the legacy tree/spec-list path.
class _RoadmapHeroView extends StatelessWidget {
  const _RoadmapHeroView({
    required this.data,
    required this.colors,
    required this.accent,
  });

  final RoadmapData data;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoadmapHero(
          nextMdContent: data.nextMdContent,
          colors: colors,
          accent: accent,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: MilestoneLanesView(
            milestones: data.milestones,
            colors: colors,
            accent: accent,
          ),
        ),
      ],
    );
  }
}

class _RoadmapSplitView extends StatefulWidget {
  const _RoadmapSplitView({
    required this.data,
    required this.source,
    required this.colors,
    required this.accent,
    required this.currentPhase,
  });

  final RoadmapData data;
  final RoadmapSource source;
  final AppColors colors;
  final Color accent;
  final String? currentPhase;

  @override
  State<_RoadmapSplitView> createState() => _RoadmapSplitViewState();
}

class _RoadmapSplitViewState extends State<_RoadmapSplitView> {
  // Selection lives in local widget state, not the provider: clicking a
  // phase/spec must not re-fetch already-resolved roadmap data (SC-005).
  RoadmapPhase? _selectedPhase;
  RoadmapSpecRef? _selectedSpec;

  void _selectPhase(RoadmapPhase phase) {
    setState(() {
      _selectedPhase = phase;
      _selectedSpec = null;
    });
  }

  void _selectSpec(RoadmapSpecRef spec) {
    setState(() => _selectedSpec = spec);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final accent = widget.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.source == RoadmapSource.vault) ...[
          const OfflineFallbackBadge(),
          const SizedBox(height: 10),
        ],
        WhatsNextIndicator(
          currentPhase: widget.currentPhase,
          colors: colors,
          accent: accent,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tree pane: ~35% width, fixed ratio — no resize handle
              // (FR-016).
              Expanded(
                flex: 35,
                child: RoadmapTree(
                  milestones: widget.data.milestones,
                  colors: colors,
                  accent: accent,
                  selectedPhase: _selectedPhase,
                  onPhaseSelected: _selectPhase,
                ),
              ),
              Container(width: 1, color: colors.bgElev.withValues(alpha: 0.8)),
              // Detail pane: ~65% width. Phase -> spec-list -> full-spec
              // navigation (Wave 4).
              Expanded(
                flex: 65,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _DetailPane(
                    colors: colors,
                    accent: accent,
                    selectedPhase: _selectedPhase,
                    selectedSpec: _selectedSpec,
                    onSpecSelected: _selectSpec,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Detail pane content: a placeholder until a phase is selected, then the
/// phase's spec list, then (on spec tap) the full spec content.
class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.colors,
    required this.accent,
    required this.selectedPhase,
    required this.selectedSpec,
    required this.onSpecSelected,
  });

  final AppColors colors;
  final Color accent;
  final RoadmapPhase? selectedPhase;
  final RoadmapSpecRef? selectedSpec;
  final ValueChanged<RoadmapSpecRef> onSpecSelected;

  @override
  Widget build(BuildContext context) {
    if (selectedSpec != null) {
      return SpecViewer(spec: selectedSpec!, colors: colors);
    }
    if (selectedPhase != null) {
      return SpecList(
        phase: selectedPhase!,
        colors: colors,
        accent: accent,
        onSpecSelected: onSpecSelected,
      );
    }
    return Center(
      child: Text(
        'Phase auswaehlen, um Details zu sehen',
        style: TextStyle(color: colors.textDim, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Exact empty-state copy required by FR-007/FR-008 — no error dialog, no
/// crash, and identical for "genuinely no data" and "slug mismatch".
class _EmptyRoadmapState extends StatelessWidget {
  const _EmptyRoadmapState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Keine Roadmap-Daten vorhanden',
        style: TextStyle(color: colors.textSec, fontSize: 14),
      ),
    );
  }
}
