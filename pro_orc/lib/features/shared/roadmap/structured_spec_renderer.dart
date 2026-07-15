import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Structured, readable renderer for a feature's spec/plan Markdown (FR-017
/// through FR-020) — replaces [SpecViewer]'s raw monospace dump for the
/// tier-0 (`docs/product/`) drill-down path.
///
/// Parses the Markdown into `##`/`###` sections and renders each one
/// semantically when its heading is recognized (Problem, User Journey,
/// Acceptance Criteria, Out of Scope, Edge Cases, Success Metrics — see
/// [_SectionKind]). Any unrecognized section, or content with no headings at
/// all, is rendered as formatted Markdown via `gpt_markdown` (FR-018) —
/// never as raw monospace plaintext.
///
/// Offers a Spec/Plan sub-tab toggle switching between [specPath] and
/// [planPath]. Missing/empty files render a graceful German "nicht
/// verfügbar" state (FR-019), carrying forward `SpecViewer._readContent()`'s
/// null-on-missing precedent.
class StructuredSpecRenderer extends StatefulWidget {
  const StructuredSpecRenderer({
    super.key,
    required this.specPath,
    required this.planPath,
    required this.colors,
  });

  /// Path to the feature's spec document, or null when the source tier does
  /// not carry one.
  final String? specPath;

  /// Path to the feature's wave-plan document, or null when the source tier
  /// does not carry one.
  final String? planPath;

  final AppColors colors;

  @override
  State<StructuredSpecRenderer> createState() => _StructuredSpecRendererState();
}

enum _DocTab { spec, plan }

class _StructuredSpecRendererState extends State<StructuredSpecRenderer> {
  _DocTab _tab = _DocTab.spec;

  /// Reads Markdown content from [path]. Returns null on any missing/blank/
  /// unreadable file — never throws (mirrors `SpecViewer._readContent()`).
  String? _readContent(String? path) {
    if (path == null) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      return content.trim().isEmpty ? null : content;
    } catch (e) {
      developer.log(
        'Failed to read doc at $path: $e',
        name: 'structured_spec_renderer',
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final activePath = _tab == _DocTab.spec ? widget.specPath : widget.planPath;
    final content = _readContent(activePath);
    final label = _tab == _DocTab.spec ? 'Spec' : 'Plan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocTabSwitch(
          tab: _tab,
          colors: colors,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: content == null
              ? _NotAvailableState(colors: colors, label: label)
              : SingleChildScrollView(
                  child: _SpecSectionList(content: content, colors: colors),
                ),
        ),
      ],
    );
  }
}

/// Segmented-control-style Spec/Plan toggle, modeled on
/// `project_detail_panel.dart`'s `_TabButton`/`_buildTabSwitch` pattern.
class _DocTabSwitch extends StatelessWidget {
  const _DocTabSwitch({
    required this.tab,
    required this.colors,
    required this.onChanged,
  });

  final _DocTab tab;
  final AppColors colors;
  final ValueChanged<_DocTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DocTabButton(
          label: 'Spec',
          selected: tab == _DocTab.spec,
          colors: colors,
          onTap: () => onChanged(_DocTab.spec),
        ),
        const SizedBox(width: 8),
        _DocTabButton(
          label: 'Plan',
          selected: tab == _DocTab.plan,
          colors: colors,
          onTap: () => onChanged(_DocTab.plan),
        ),
      ],
    );
  }
}

class _DocTabButton extends StatelessWidget {
  const _DocTabButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? colors.cyan.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? colors.cyan.withValues(alpha: 0.4)
                  : colors.bgElev,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.cyan : colors.textDim,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Graceful "nicht verfügbar" fallback (FR-019) — covers a null path, a
/// missing file, and a blank file uniformly.
class _NotAvailableState extends StatelessWidget {
  const _NotAvailableState({required this.colors, required this.label});

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 28, color: colors.textDim),
          const SizedBox(height: 10),
          Text(
            '$label nicht verfügbar',
            style: TextStyle(color: colors.textDim, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Parses [content] into sections and renders each with the widget matching
/// its recognized kind, or as formatted Markdown when unrecognized.
class _SpecSectionList extends StatelessWidget {
  const _SpecSectionList({required this.content, required this.colors});

  final String content;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          _SectionRenderer(section: section, colors: colors),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// One `##`/`###` heading section plus its body text.
class _Section {
  const _Section({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// Splits Markdown [content] on `##`/`###` headings. Any leading content
/// before the first heading becomes a section with an empty heading (still
/// rendered via the freeform Markdown fallback).
List<_Section> _parseSections(String content) {
  final headingPattern = RegExp(r'^(#{2,3})\s+(.+)$', multiLine: true);
  final matches = headingPattern.allMatches(content).toList();

  if (matches.isEmpty) {
    return [_Section(heading: '', body: content.trim())];
  }

  final sections = <_Section>[];

  final firstMatchStart = matches.first.start;
  if (firstMatchStart > 0) {
    final leading = content.substring(0, firstMatchStart).trim();
    if (leading.isNotEmpty) {
      sections.add(_Section(heading: '', body: leading));
    }
  }

  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final heading = match.group(2)!.trim();
    final bodyStart = match.end;
    final bodyEnd = i + 1 < matches.length
        ? matches[i + 1].start
        : content.length;
    final body = content.substring(bodyStart, bodyEnd).trim();
    sections.add(_Section(heading: heading, body: body));
  }

  return sections;
}

/// Recognized structured-section kinds (FR-017). Matching is tolerant of
/// the "Discovery — X" prefix (a1-specforge vocabulary), case, and German
/// variants (e.g. "Erfolgsmetriken").
enum _SectionKind {
  problem,
  userJourney,
  acceptanceCriteria,
  outOfScope,
  edgeCases,
  successMetrics,
  freeform,
}

_SectionKind _classify(String heading) {
  final normalized = heading
      .toLowerCase()
      .replaceAll(RegExp(r'^discovery\s*[—\-–]\s*'), '')
      .trim();

  if (normalized == 'problem') return _SectionKind.problem;
  if (normalized == 'user journey' || normalized == 'user stories') {
    return _SectionKind.userJourney;
  }
  if (normalized == 'acceptance criteria') {
    return _SectionKind.acceptanceCriteria;
  }
  if (normalized == 'out of scope') return _SectionKind.outOfScope;
  if (normalized == 'edge cases') return _SectionKind.edgeCases;
  if (normalized == 'success metrics' || normalized == 'erfolgsmetriken') {
    return _SectionKind.successMetrics;
  }
  return _SectionKind.freeform;
}

/// Renders one [_Section] with the widget matching its recognized kind.
class _SectionRenderer extends StatelessWidget {
  const _SectionRenderer({required this.section, required this.colors});

  final _Section section;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final kind = section.heading.isEmpty
        ? _SectionKind.freeform
        : _classify(section.heading);
    final bulletLines = _bulletLines(section.body);

    return switch (kind) {
      _SectionKind.acceptanceCriteria => _SectionHeading(
        heading: section.heading,
        colors: colors,
        child: _ChecklistSection(lines: bulletLines, colors: colors),
      ),
      _SectionKind.outOfScope => _SectionHeading(
        heading: section.heading,
        colors: colors,
        child: _InfoBoxSection(lines: bulletLines, colors: colors),
      ),
      _SectionKind.edgeCases => _SectionHeading(
        heading: section.heading,
        colors: colors,
        child: _WarningCardsSection(lines: bulletLines, colors: colors),
      ),
      _SectionKind.successMetrics => _SectionHeading(
        heading: section.heading,
        colors: colors,
        child: _MetricsTilesSection(lines: bulletLines, colors: colors),
      ),
      _SectionKind.problem || _SectionKind.userJourney => _SectionHeading(
        heading: section.heading,
        colors: colors,
        child: _ProseSection(body: section.body, colors: colors),
      ),
      _SectionKind.freeform =>
        section.heading.isEmpty
            ? _FreeformMarkdown(body: section.body, colors: colors)
            : _SectionHeading(
                heading: section.heading,
                colors: colors,
                child: _FreeformMarkdown(body: section.body, colors: colors),
              ),
    };
  }

  /// Extracts `- ` / `* ` bullet lines from a section body, stripped of the
  /// bullet marker. Falls back to non-empty raw lines when no bullets are
  /// present (defensive — keeps the semantic renderers usable even for
  /// slightly malformed input).
  List<String> _bulletLines(String body) {
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final bullets = lines
        .where((l) => l.startsWith('- ') || l.startsWith('* '))
        .map((l) => l.substring(2).trim())
        .toList();
    return bullets.isNotEmpty ? bullets : lines;
  }
}

/// Section title, styled consistently across all recognized-section kinds.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.heading,
    required this.colors,
    required this.child,
  });

  final String heading;
  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            color: colors.textPri,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Acceptance Criteria → checklist with check icons (FR-017).
class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.lines, required this.colors});

  final List<String> lines;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: colors.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(color: colors.textSec, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Out of Scope → framed info box with a dampened background (FR-017).
class _InfoBoxSection extends StatelessWidget {
  const _InfoBoxSection({required this.lines, required this.colors});

  final List<String> lines;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('out_of_scope_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.bgElev),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block_outlined, size: 14, color: colors.textDim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(color: colors.textDim, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Edge Cases → warning-accented cards, one per line (FR-017).
class _WarningCardsSection extends StatelessWidget {
  const _WarningCardsSection({required this.lines, required this.colors});

  final List<String> lines;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(color: colors.textSec, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Success Metrics → compact stat tiles in a grid (FR-017).
class _MetricsTilesSection extends StatelessWidget {
  const _MetricsTilesSection({required this.lines, required this.colors});

  final List<String> lines;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('success_metrics_grid'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final line in lines)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.trending_up, size: 14, color: colors.cyan),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      line,
                      style: TextStyle(color: colors.textSec, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Problem / User Journey → readable prose block (rendered via Markdown so
/// any inline emphasis still shows correctly, never monospace).
class _ProseSection extends StatelessWidget {
  const _ProseSection({required this.body, required this.colors});

  final String body;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return _FreeformMarkdown(body: body, colors: colors);
  }
}

/// Unrecognized section (or content with no headings at all) → formatted
/// Markdown via `gpt_markdown` (FR-018). Never raw monospace plaintext.
class _FreeformMarkdown extends StatelessWidget {
  const _FreeformMarkdown({required this.body, required this.colors});

  final String body;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    return GptMarkdown(
      body,
      style: TextStyle(color: colors.textSec, fontSize: 12.5, height: 1.5),
    );
  }
}
