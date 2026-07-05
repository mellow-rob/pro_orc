/// Immutable models for the a1 learning loop view (M6 Wave 1).
///
/// The learning loop lives in two places:
///   1. The Obsidian Vault under `pattern/a1-learnings/` — per-skill retro files
///      (a1-execute.md, a1-plan.md, …) and a `patterns.md` synthesis index.
///   2. Per-project `.a1/phases/*/observations.jsonl` — inline observations
///      written during execution.
///
/// All fields are read-only; the app never writes into the vault (AD-1..AD-3).
library;

/// Retro statistics for a single a1 skill (one `pattern/a1-learnings/<skill>.md`).
class SkillRetro {
  /// Skill name derived from the filename, e.g. `a1-execute`.
  final String skill;

  /// Number of retro entries found in the file (counted defensively — see
  /// `LearningReader`).
  final int retroCount;

  /// Absolute path to the retro markdown file, for "Im Finder zeigen" /
  /// "In Obsidian öffnen".
  final String absolutePath;

  /// Last modification time of the file, or null if unavailable.
  final DateTime? lastModified;

  const SkillRetro({
    required this.skill,
    required this.retroCount,
    required this.absolutePath,
    this.lastModified,
  });
}

/// Observation counts for a single project's `.a1/phases/*/observations.jsonl`.
class ProjectObservations {
  /// Display name of the project (folder basename).
  final String project;

  /// Absolute path to the project directory.
  final String projectPath;

  /// Total number of valid JSONL observation lines across all phases.
  final int observationCount;

  /// Timestamp of the most recent observation, if any line carried a parseable
  /// `ts`/`timestamp` field.
  final DateTime? lastObservation;

  const ProjectObservations({
    required this.project,
    required this.projectPath,
    required this.observationCount,
    this.lastObservation,
  });
}

/// Aggregated learning-loop state. Produced by `LearningReader.read`.
class LearningData {
  /// Per-skill retro stats, sorted by skill name.
  final List<SkillRetro> retrosPerSkill;

  /// Pattern-cluster titles extracted from `patterns.md` (applied + monitored).
  final List<String> patternClusters;

  /// Per-project observation counts, sorted by project name. Only projects that
  /// actually have an `.a1/phases/*/observations.jsonl` appear here.
  final List<ProjectObservations> observations;

  /// Heuristic count of retro entries newer than the last `patterns.md`
  /// modification — i.e. learnings not yet folded into a synthesis. Drives the
  /// "a1-evolve fällig" banner when it reaches [evolveThreshold].
  final int totalSinceLastSynthesis;

  /// Absolute path to the vault's `pattern/a1-learnings/` directory, or null
  /// when the vault (or that subfolder) does not exist.
  final String? learningsRootPath;

  /// Absolute path to `patterns.md`, or null when absent.
  final String? patternsFilePath;

  const LearningData({
    this.retrosPerSkill = const [],
    this.patternClusters = const [],
    this.observations = const [],
    this.totalSinceLastSynthesis = 0,
    this.learningsRootPath,
    this.patternsFilePath,
  });

  static const empty = LearningData();

  /// a1-evolve is suggested once at least this many retros accumulate since the
  /// last synthesis (per the a1-framework "~5 Runs" rule).
  static const int evolveThreshold = 5;

  /// True when a synthesis run (a1-evolve) is due.
  bool get evolveDue => totalSinceLastSynthesis >= evolveThreshold;

  /// Total retro entries across all skills.
  int get totalRetros =>
      retrosPerSkill.fold(0, (sum, r) => sum + r.retroCount);

  bool get isEmpty =>
      retrosPerSkill.isEmpty &&
      patternClusters.isEmpty &&
      observations.isEmpty;
}
