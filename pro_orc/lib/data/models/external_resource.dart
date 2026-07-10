/// Enum representing the type of external resource linked to a project.
enum ExternalResourceType {
  /// GitHub repository
  github,

  /// Figma design file
  figma,

  /// Claude project memory directory (~/.claude/projects/...)
  claudeMemory,

  /// Any other detected external URL
  other,
}

/// An external resource (URL or filesystem path) associated with a project.
///
/// Resources are detected by [detectExternalResources] and displayed in the
/// project deletion flow so the user knows what to clean up manually.
class ExternalResource {
  /// The category of this resource.
  final ExternalResourceType type;

  /// Human-readable German label, e.g. "GitHub-Repository", "Figma-Design".
  final String label;

  /// The URL or absolute filesystem path to the resource.
  final String uri;

  /// German hint explaining what deletion means for this resource type.
  /// Informational only — the app does NOT auto-delete external resources.
  final String hint;

  const ExternalResource({
    required this.type,
    required this.label,
    required this.uri,
    required this.hint,
  });
}
