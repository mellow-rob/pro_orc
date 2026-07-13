/// Result of validating a candidate group name against the current group
/// list. Returned by [GroupsNotifier.create]/[GroupsNotifier.rename] instead
/// of throwing, so Wave 4's UI can turn a failure into an inline error
/// message (e.g. "Gruppe existiert bereits").
sealed class GroupNameValidation {
  const GroupNameValidation();
}

/// The candidate name is valid and safe to persist.
class GroupNameValid extends GroupNameValidation {
  final String trimmedName;

  const GroupNameValid(this.trimmedName);
}

/// The trimmed name is empty.
class GroupNameEmpty extends GroupNameValidation {
  const GroupNameEmpty();
}

/// The trimmed, case-insensitive name collides with an existing group name
/// (including the reserved "Archiv" system group).
class GroupNameDuplicate extends GroupNameValidation {
  final String collidingName;

  const GroupNameDuplicate(this.collidingName);
}

/// Trims [candidate] and checks it for emptiness and case-insensitive
/// collisions against [existingNames] (which must include "Archiv" — the
/// reserved system-group name — by the caller passing the full current
/// group list).
///
/// [excludeName] lets a rename check against all names except the group's
/// own current name (a no-op rename to the same name is not a collision).
GroupNameValidation validateGroupName(
  String candidate,
  Iterable<String> existingNames, {
  String? excludeName,
}) {
  final trimmed = candidate.trim();
  if (trimmed.isEmpty) return const GroupNameEmpty();

  final normalizedExclude = excludeName?.trim().toLowerCase();
  final normalizedCandidate = trimmed.toLowerCase();

  for (final existing in existingNames) {
    final normalizedExisting = existing.trim().toLowerCase();
    if (normalizedExclude != null && normalizedExisting == normalizedExclude) {
      continue;
    }
    if (normalizedExisting == normalizedCandidate) {
      return GroupNameDuplicate(existing);
    }
  }

  return GroupNameValid(trimmed);
}
