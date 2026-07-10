/// Generic project lifecycle status, independent of any specific parser or
/// data source (previously named `GsdStatus`, tied to the now-removed GSD
/// legacy system — this is a plain string-normalization enum reused by the
/// Roadmap tab, see `deriveDisplayStatus`).
enum DisplayStatus { research, planning, building, paused, done, archived }

/// Normalizes a raw status string (e.g. "in progress", "shipped", "wip")
/// to a [DisplayStatus] enum value. Returns null for unrecognized status
/// strings.
///
/// This is generic string -> status vocabulary, not tied to any single
/// data source — reused across features that need consistent status
/// wording (e.g. the Roadmap tab, FR-003: "keine neuen Status-Woerter fuer
/// den Roadmap-Tab einfuehren").
DisplayStatus? deriveDisplayStatus(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('research')) return DisplayStatus.research;
  if (lower.contains('plan')) return DisplayStatus.planning;
  if (lower.contains('build') || lower.contains('progress')) {
    return DisplayStatus.building;
  }
  if (lower.contains('pause')) return DisplayStatus.paused;
  if (lower.contains('done') ||
      lower.contains('complete') ||
      lower.contains('finish') ||
      lower.contains('shipped')) {
    return DisplayStatus.done;
  }
  if (lower.contains('archive')) return DisplayStatus.archived;
  return null;
}
