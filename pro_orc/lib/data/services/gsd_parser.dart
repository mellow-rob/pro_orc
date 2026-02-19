import 'dart:io';

import '../models/gsd_data.dart';

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

// ROADMAP.md — Plan checkboxes
final _rPlanDone = RegExp(r'^- \[[xX]\]\s+\d+-\d+-PLAN', multiLine: true);
final _rPlanPending = RegExp(r'^- \[ \]\s+\d+-\d+-PLAN', multiLine: true);

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
    } catch (_) {
      hasParseError = true;
    }
  }

  // Parse ROADMAP.md
  int? plansCompleted;
  int? plansTotal;
  int? phaseProgress;

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
