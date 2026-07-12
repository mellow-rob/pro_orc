/// Immutable models for discovered automations/workflows (M6 Wave 3).
///
/// Per AD-3 there is no stable, documented storage format for Claude Code
/// "routines", so discovery is strictly best-effort across three sources the
/// user actually has on macOS:
///   - launchd user agents (`~/Library/LaunchAgents/*.plist`) invoking `claude`,
///   - the user crontab (`crontab -l`) invoking `claude`,
///   - Stop/Cron hooks already surfaced by the harness reader (hooks ARE
///     workflows — they run automatically on events).
///
/// Nothing is started or stopped; the view is read-only.
library;

/// Where a discovered automation came from.
enum AutomationSource {
  /// A `launchd` user agent under `~/Library/LaunchAgents`.
  launchd,

  /// A line from the user's `crontab`.
  cron,

  /// A Claude Code hook (from the harness config) that fires on an event.
  hook,
}

extension AutomationSourceLabel on AutomationSource {
  /// Short German-facing badge label.
  String get label => switch (this) {
    AutomationSource.launchd => 'launchd',
    AutomationSource.cron => 'cron',
    AutomationSource.hook => 'Hook',
  };
}

/// A single discovered automation.
class Automation {
  /// Human-readable name: the plist Label, the hook event (+matcher), or a
  /// short cron-schedule summary.
  final String name;

  /// The command/script that runs, already secret-masked for display.
  final String command;

  /// A schedule/trigger hint when known (e.g. `RunAtLoad`, `0 9 * * *`,
  /// `Stop`). Empty when not applicable.
  final String schedule;

  final AutomationSource source;

  const Automation({
    required this.name,
    required this.command,
    required this.schedule,
    required this.source,
  });
}

/// Aggregated automations across all sources. Produced by `AutomationReader`.
class AutomationData {
  final List<Automation> automations;

  const AutomationData({this.automations = const []});

  static const empty = AutomationData();

  bool get isEmpty => automations.isEmpty;

  /// Automations grouped by source, preserving list order within each group.
  List<Automation> ofSource(AutomationSource source) =>
      automations.where((a) => a.source == source).toList();
}
