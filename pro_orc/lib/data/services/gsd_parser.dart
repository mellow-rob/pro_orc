import 'dart:io';

import '../models/gsd_data.dart';
import '../models/phase_info.dart';

export '../models/gsd_data.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class GsdParseResult {
  final GsdData gsd;
  final String? displayName;
  final String? description;
  final bool hasParseError;

  const GsdParseResult({
    required this.gsd,
    this.displayName,
    this.description,
    this.hasParseError = false,
  });
}

// ---------------------------------------------------------------------------
// Top-level regex patterns (compiled once)
// ---------------------------------------------------------------------------

// STATE.md — Phase
final _rPhase = RegExp(r'^\*\*(?:Current )?Phase:\*\*\s*(.+)$', multiLine: true);
final _rPhasePlain = RegExp(r'^Phase:\s*(.+)$', multiLine: true);

// STATE.md — Status
final _rStatus = RegExp(r'^\*\*Status:\*\*\s*(.+)$', multiLine: true);
final _rStatusPlain = RegExp(r'^Status:\s*(.+)$', multiLine: true);

// STATE.md — Next step (three variants)
final _rNextAction = RegExp(r'^\*\*Next Action:\*\*\s*(.+)$', multiLine: true);
final _rNextStep = RegExp(r'^\*\*Next Step:\*\*\s*(.+)$', multiLine: true);
final _rNextStepDE = RegExp(r'^\*\*Nächster Schritt:\*\*\s*(.+)$', multiLine: true);
final _rNextStepPlain = RegExp(r'^Next Step:\s*(.+)$', multiLine: true);

// STATE.md — Version (first vN.N or vN.N.N occurrence)
final _rVersion = RegExp(r'v(\d+\.\d+(?:\.\d+)?)', caseSensitive: false);

// STATE.md — Decisions section
final _rDecisionSection = RegExp(
  r'### Decisions\s*\n([\s\S]*?)(?:\n### |\n## |$)',
  multiLine: true,
);
final _rDecisionBullet = RegExp(r'^- (.+)$', multiLine: true);

// ROADMAP.md — Plan checkboxes
final _rPlanDone = RegExp(r'^- \[[xX]\]\s+\d+-\d+-PLAN', multiLine: true);
final _rPlanPending = RegExp(r'^- \[ \]\s+\d+-\d+-PLAN', multiLine: true);

// ROADMAP.md — Phase headings: "### Phase N: Name"
final _rPhaseEntry = RegExp(
  r'###\s+Phase\s+(\d+):\s+(.+?)$',
  multiLine: true,
);
// Matches "N/N plans complete" in a phase block
final _rPhaseComplete = RegExp(r'\b(\d+)/(\d+)\s+plans?\s+complete', caseSensitive: false);
// Matches "**Plans:** N plans" in a phase block
final _rPhasePlanCount = RegExp(r'\*\*Plans:\*\*\s*(\d+)\s+plans?', caseSensitive: false);

// PROJECT.md — Notion URL
final _rNotion = RegExp(r'<!--\s*notion:\s*(https?://[^\s>]+)\s*-->', caseSensitive: false);

// PROJECT.md — H1 heading (first match)
final _rH1 = RegExp(r'^#\s+(.+)$', multiLine: true);

// PROJECT.md — Description section heading then first paragraph
final _rDescSection = RegExp(
  r'^##\s+(?:Core Value|Kernwert|Was ist das|What This Is|What is this)\s*\n+([\s\S]+?)(?:\n\n|\n##|$)',
  multiLine: true,
  caseSensitive: false,
);

// Strip bold markers **text**
final _rBold = RegExp(r'\*\*([^*]+)\*\*');

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse GSD data for a project rooted at [projectPath].
///
/// Returns [GsdParseResult] with [GsdData.empty] and no error when
/// `.planning/` does not exist (non-GSD project).
Future<GsdParseResult> parseGsdData(String projectPath) async {
  final planningDir = Directory('$projectPath/.planning');
  if (!await planningDir.exists()) {
    return GsdParseResult(gsd: GsdData.empty);
  }

  // Read all three files concurrently
  final results = await Future.wait([
    _safeRead('$projectPath/.planning/STATE.md'),
    _safeRead('$projectPath/.planning/ROADMAP.md'),
    _safeRead('$projectPath/.planning/PROJECT.md'),
  ]);

  final stateContent = results[0];
  final roadmapContent = results[1];
  final projectContent = results[2];

  bool hasParseError = false;

  // Parse STATE.md
  String? currentPhase;
  String? status;
  String? nextStep;
  String? version;
  List<String>? decisions;

  if (stateContent != null) {
    try {
      currentPhase = _firstMatch(_rPhase, stateContent) ??
          _firstMatch(_rPhasePlain, stateContent);
      final rawStatus = _firstMatch(_rStatus, stateContent) ??
          _firstMatch(_rStatusPlain, stateContent);
      status = rawStatus != null ? _deriveStatus(rawStatus) : null;
      nextStep = _firstMatch(_rNextAction, stateContent) ??
          _firstMatch(_rNextStep, stateContent) ??
          _firstMatch(_rNextStepDE, stateContent) ??
          _firstMatch(_rNextStepPlain, stateContent);

      // Extract version (first vN.N occurrence)
      final vMatch = _rVersion.firstMatch(stateContent);
      version = vMatch != null ? 'v${vMatch.group(1)}' : null;

      // Extract decisions from ### Decisions section
      final sectionMatch = _rDecisionSection.firstMatch(stateContent);
      if (sectionMatch != null) {
        final sectionText = sectionMatch.group(1) ?? '';
        final bullets = _rDecisionBullet
            .allMatches(sectionText)
            .map((m) => m.group(1)!.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (bullets.isNotEmpty) decisions = bullets;
      }
    } catch (_) {
      hasParseError = true;
    }
  }

  // Parse ROADMAP.md
  int? plansCompleted;
  int? plansTotal;
  int? phaseProgress;
  List<PhaseInfo>? phases;

  if (roadmapContent != null) {
    try {
      final done = _rPlanDone.allMatches(roadmapContent).length;
      final pending = _rPlanPending.allMatches(roadmapContent).length;
      final total = done + pending;
      if (total > 0) {
        plansCompleted = done;
        plansTotal = total;
        phaseProgress = (done / total * 100).round();
      }

      // Extract phase list from ### Phase N: Name headings
      final phaseMatches = _rPhaseEntry.allMatches(roadmapContent).toList();
      if (phaseMatches.isNotEmpty) {
        final phaseList = <PhaseInfo>[];
        for (var i = 0; i < phaseMatches.length; i++) {
          final match = phaseMatches[i];
          final number = int.tryParse(match.group(1) ?? '') ?? 0;
          final name = match.group(2)?.trim() ?? '';

          // Extract the text block between this phase heading and the next
          final start = match.end;
          final end = (i + 1 < phaseMatches.length)
              ? phaseMatches[i + 1].start
              : roadmapContent.length;
          final block = roadmapContent.substring(start, end);

          // Determine plan counts from block
          int pc = 0, pt = 0;
          final completeMatch = _rPhaseComplete.firstMatch(block);
          if (completeMatch != null) {
            pc = int.tryParse(completeMatch.group(1) ?? '') ?? 0;
            pt = int.tryParse(completeMatch.group(2) ?? '') ?? 0;
          } else {
            // Count checkboxes within block
            final doneCount = _rPlanDone.allMatches(block).length;
            final pendingCount = _rPlanPending.allMatches(block).length;
            pc = doneCount;
            pt = doneCount + pendingCount;
            // Fallback: check "**Plans:** N plans" line
            if (pt == 0) {
              final countMatch = _rPhasePlanCount.firstMatch(block);
              if (countMatch != null) {
                pt = int.tryParse(countMatch.group(1) ?? '') ?? 0;
              }
            }
          }

          // Determine status
          String phaseStatus;
          if (pc > 0 && pc >= pt && pt > 0) {
            phaseStatus = 'complete';
          } else if (pc > 0 || block.toLowerCase().contains('in progress')) {
            phaseStatus = 'in_progress';
          } else {
            phaseStatus = 'not_started';
          }

          phaseList.add(PhaseInfo(
            number: number,
            name: name,
            status: phaseStatus,
            plansCompleted: pc,
            plansTotal: pt,
          ));
        }
        if (phaseList.isNotEmpty) phases = phaseList;
      }
    } catch (_) {
      hasParseError = true;
    }
  }

  // Parse PROJECT.md
  String? displayName;
  String? notionUrl;
  String? description;

  if (projectContent != null) {
    try {
      // H1 heading
      final h1Match = _rH1.firstMatch(projectContent);
      if (h1Match != null) {
        displayName = h1Match.group(1)?.trim();
      }

      // Notion URL
      final notionMatch = _rNotion.firstMatch(projectContent);
      if (notionMatch != null) {
        notionUrl = notionMatch.group(1)?.trim();
      }

      // Description
      final descMatch = _rDescSection.firstMatch(projectContent);
      if (descMatch != null) {
        var desc = descMatch.group(1)?.trim() ?? '';
        // Take first paragraph (stop at blank line)
        final firstPara = desc.split('\n\n').first.trim();
        // Strip bold markers
        desc = firstPara.replaceAllMapped(_rBold, (m) => m.group(1)!);
        // Truncate to 200 chars
        if (desc.length > 200) desc = desc.substring(0, 200);
        description = desc.isEmpty ? null : desc;
      }
    } catch (_) {
      hasParseError = true;
    }
  }

  final gsd = GsdData(
    status: status,
    currentPhase: currentPhase,
    nextStep: nextStep,
    phaseProgress: phaseProgress,
    notionUrl: notionUrl,
    description: description,
    plansCompleted: plansCompleted,
    plansTotal: plansTotal,
    version: version,
    phases: phases,
    decisions: decisions,
  );

  return GsdParseResult(
    gsd: gsd,
    displayName: displayName,
    description: description,
    hasParseError: hasParseError,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads a file safely; returns null on any error.
Future<String?> _safeRead(String path) async {
  try {
    return await File(path).readAsString();
  } catch (_) {
    return null;
  }
}

/// Returns the first capture group of [pattern] in [text], trimmed.
String? _firstMatch(RegExp pattern, String text) {
  return pattern.firstMatch(text)?.group(1)?.trim();
}

/// Normalizes a raw status string to one of:
/// research | planning | building | paused | done | archived
String _deriveStatus(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('research')) { return 'research'; }
  if (lower.contains('plan')) { return 'planning'; }
  if (lower.contains('build') || lower.contains('progress')) { return 'building'; }
  if (lower.contains('pause')) { return 'paused'; }
  if (lower.contains('done') ||
      lower.contains('complete') ||
      lower.contains('finish')) { return 'done'; }
  if (lower.contains('archive')) { return 'archived'; }
  return lower.trim();
}
