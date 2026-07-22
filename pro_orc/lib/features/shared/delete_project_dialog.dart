import 'dart:async' show unawaited;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/deletion_result.dart';
import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/deletion_service.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/data/services/resource_detector.dart';
import 'package:pro_orc/data/services/vercel_detection_service.dart';
import 'package:pro_orc/features/shared/github_permission_popup.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Runs the GitHub `delete_repo` OAuth scope pre-flight check. Matches
/// [GhDetectionService.checkDeleteRepoScope]'s signature so the real service
/// method can be passed directly as the default; tests inject a fake that
/// returns a canned [GhScopeStatus] (and can count calls) without spawning a
/// real `gh` process (Spec 008, FR-002/FR-003/FR-006).
typedef GhScopeChecker = Future<GhScopeStatus> Function();

/// The dialog's current screen.
///
/// `form` → (checked destructive-external resource?) → `destructiveWarning`
/// → `running` → `result`. A Claude-memory-only (or empty) selection skips
/// straight from `form` to `running` — the extra "cannot be undone" warning
/// (FR-007) is required only when a destructive-external resource
/// (Vercel/GitHub) is checked. There is no code path that reaches `running`
/// with a checked destructive-external resource except via
/// `destructiveWarning` (SC-004 — no bypass).
enum _DialogStep {
  /// Main form: resource checkboxes, project-name confirmation, buttons.
  form,

  /// Dedicated full-step "cannot be undone" screen (Variant A), shown only
  /// when at least one checked resource is destructive-external.
  destructiveWarning,

  /// Deletion flow in progress. The dialog is not closable (no close
  /// button, no barrier dismiss, no cancel) and "Loeschen" cannot be
  /// re-triggered (FR-015/FR-016) until [result].
  running,

  /// Final per-resource report. Ends with an explicit "Schliessen" action;
  /// never auto-closes (FR-018).
  result,
}

/// GitHub-style deletion confirmation dialog with external resource detection.
///
/// Requires the user to type the exact project name before enabling
/// the "Loeschen" button — prevents accidental permanent deletion. If a
/// checked resource is destructive-external (Vercel/GitHub), an additional
/// "cannot be undone" step (FR-007) is required before the flow starts.
///
/// On confirm: calls [deleteProject], invalidates [projectsProvider]
/// for auto-refresh. If resources were selected, shows a post-deletion
/// result report before closing. Otherwise pops immediately.
/// On cancel (from the main form only): pops with `false` — no side
/// effects.
///
/// [vercelDetectionService] and [ghDetectionService] gate whether Vercel/
/// GitHub resources render an active-delete checkbox (default real
/// services, overridable in tests — mirrors the project's `whichCommand`
/// injection convention). Availability is resolved from the CLIs' own
/// existing local login state only; no token is ever entered into or
/// stored by Pro Orc (FR-013).
class DeleteProjectDialog extends ConsumerStatefulWidget {
  const DeleteProjectDialog({
    super.key,
    required this.project,
    this.vercelDetectionService = const VercelDetectionService(),
    this.ghDetectionService = const GhDetectionService(),
    this.ghRunner = defaultProcessRunner,
    this.vercelRunner = defaultVercelProcessRunner,
    this.checkDeleteRepoScope,
    this.onOpenTerminalForGhScopeRefresh,
  });

  final ProjectModel project;
  final VercelDetectionService vercelDetectionService;
  final GhDetectionService ghDetectionService;

  /// Injectable `gh` CLI process runner used for active GitHub deletion
  /// (mirrors the `whichCommand` injection convention) — default real
  /// `Process.run`, overridable in tests so `gh repo delete` outcomes can
  /// be simulated without spawning real processes.
  final ProcessRunner ghRunner;

  /// Injectable Vercel CLI process runner used for active Vercel project
  /// deletion — default real (spawns `vercel`, answers its confirmation
  /// prompt via stdin, times out after 15s — see [defaultVercelProcessRunner]),
  /// overridable in tests so `vercel project remove` outcomes can be
  /// simulated without spawning real processes.
  final VercelProcessRunner vercelRunner;

  /// Injectable GitHub `delete_repo` OAuth scope pre-flight checker (Spec
  /// 008, Wave 1's `GhDetectionService.checkDeleteRepoScope`). `null` (the
  /// default) resolves to `ghDetectionService.checkDeleteRepoScope` at call
  /// time in the state, mirroring the `ghDetectionService`/`vercelRunner`
  /// injection convention — overridable in tests so present/missing/
  /// checkFailed/cliUnavailable outcomes can be simulated without spawning
  /// a real `gh` process.
  final GhScopeChecker? checkDeleteRepoScope;

  /// Invoked when the user taps the missing-permission popup's action
  /// button to open a terminal and re-request the `delete_repo` scope.
  /// `null` (the default) resolves to
  /// `QuickActionsService().openTerminalWithGhScopeRefresh` at call time —
  /// overridable in tests so the real AppleScript/Terminal launch never
  /// runs during widget tests.
  final Future<void> Function()? onOpenTerminalForGhScopeRefresh;

  @override
  ConsumerState<DeleteProjectDialog> createState() =>
      _DeleteProjectDialogState();
}

class _DeleteProjectDialogState extends ConsumerState<DeleteProjectDialog> {
  late final TextEditingController _textController;

  /// Current screen. See [_DialogStep] for the allowed transitions.
  _DialogStep _step = _DialogStep.form;

  /// null = still loading, empty = none found
  List<ExternalResource>? _resources;

  /// URIs of resources the user wants to clean up (unchecked by default)
  final Set<String> _selectedResources = {};

  /// External-deletion outcomes keyed by resource URI, populated as each
  /// [DeletionResult] arrives during [_DialogStep.running] — absent means
  /// still in progress (spinner row), present means the row can flip to a
  /// success/failure icon. Never contains an entry for a Figma resource
  /// (FR-010 — never dispatched) or the local-folder deletion (surfaced
  /// separately via [_localDeleteSucceeded]).
  final Map<String, DeletionResult> _externalResults = {};

  /// null = local folder/DB deletion not yet finished; true/false once
  /// [deleteProject] has returned. Runs independently of the external
  /// deletions (FR-008) — a failed/slow external deletion never blocks it.
  bool? _localDeleteSucceeded;

  /// null = still resolving availability, true/false = resolved.
  /// Gates whether Vercel/GitHub resources render an active-delete
  /// checkbox (FR-003/FR-004/FR-006) — never gated on a stored token
  /// (FR-013).
  bool? _vercelAvailable;
  bool? _ghAvailable;

  /// Last-known GitHub `delete_repo` scope pre-flight result per GitHub
  /// resource URI (Spec 008, Wave 3). Absent means "not yet checked in this
  /// dialog session" — treated as blocked/not-actively-checkable, the same
  /// as [GhScopeStatus.missing], never as [GhScopeStatus.present]. This map
  /// is informational only (drives no caching/short-circuit logic): every
  /// checkbox tick to `true` runs a brand-new [_checkGithubScope] call
  /// regardless of what is stored here (FR-006 — no stale/cached reuse
  /// within the same dialog session).
  final Map<String, GhScopeStatus> _ghScopeResults = {};

  /// URIs of GitHub resources with a [_checkGithubScope] call currently in
  /// flight (Spec 008 review fix — In-flight-Race Finding 1). Non-empty
  /// means at least one selected resource's active-delete eligibility is
  /// still unconfirmed:
  /// - [_onDeleteButtonPressed] must not start the deletion flow while a
  ///   pending check exists for a currently-selected resource (Finding
  ///   1a) — the "Loeschen" button is disabled for the duration instead
  ///   (immediate visible feedback).
  /// - [_checkGithubScope] must not show [GithubPermissionPopup] once the
  ///   check resolves if the user already unchecked the resource in the
  ///   meantime (Finding 1b) — the late popup would contradict the user's
  ///   own already-reverted decision.
  final Set<String> _pendingScopeChecks = {};

  /// Whether any currently *selected* resource still has a GitHub scope
  /// check in flight. Only resources still in [_selectedResources] count —
  /// a pending check for a resource the user already unchecked does not
  /// block deletion (there is nothing destructive-external left to guard).
  bool get _hasPendingScopeCheckForSelected {
    if (_pendingScopeChecks.isEmpty) return false;
    return _pendingScopeChecks.any(_selectedResources.contains);
  }

  /// Resolves once both [_loadResources] and [_resolveAvailability] have
  /// settled. Exposed only so widget tests can await the dialog's initial
  /// async load (both spawn real processes / do real file I/O that
  /// `tester.pumpAndSettle()` does not wait for) instead of polling or
  /// guessing a fixed delay.
  @visibleForTesting
  late final Future<void> initialLoad;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() => setState(() {}));
    initialLoad = Future.wait([_loadResources(), _resolveAvailability()]);
  }

  Future<void> _loadResources() async {
    try {
      final resources = await detectExternalResources(widget.project);
      if (mounted) setState(() => _resources = resources);
    } catch (e) {
      developer.log(
        'Failed to detect external resources for ${widget.project.path}: $e',
        name: 'delete_project_dialog',
      );
      if (mounted) setState(() => _resources = []);
    }
  }

  Future<void> _resolveAvailability() async {
    try {
      final vercelAvailable = await widget.vercelDetectionService.isAvailable();
      if (mounted) setState(() => _vercelAvailable = vercelAvailable);
    } catch (e) {
      developer.log(
        'Failed to resolve Vercel CLI availability: $e',
        name: 'delete_project_dialog',
      );
      if (mounted) setState(() => _vercelAvailable = false);
    }

    try {
      final ghAvailable = await widget.ghDetectionService.isAvailable();
      if (mounted) setState(() => _ghAvailable = ghAvailable);
    } catch (e) {
      developer.log(
        'Failed to resolve gh CLI availability: $e',
        name: 'delete_project_dialog',
      );
      if (mounted) setState(() => _ghAvailable = false);
    }
  }

  /// Whether [resource] is eligible for active (real) deletion rather than
  /// hint-only display. Claude memory has no CLI dependency (FR-005);
  /// Vercel/GitHub are gated on the matching CLI's resolved availability
  /// (FR-003/FR-004/FR-006). Figma and other URL types are permanently
  /// hint-only (FR-010, out of scope for active deletion in any wave).
  bool _isActivelyDeletable(ExternalResource resource) {
    switch (resource.type) {
      case ExternalResourceType.claudeMemory:
        return true;
      case ExternalResourceType.vercel:
        return _vercelAvailable == true;
      case ExternalResourceType.github:
        return _ghAvailable == true;
      case ExternalResourceType.figma:
      case ExternalResourceType.other:
        return false;
    }
  }

  /// Runs a brand-new GitHub `delete_repo` scope pre-flight check for
  /// [resource] and reacts to the result (Spec 008, FR-002/FR-003/FR-005/
  /// FR-006/FR-011/FR-012).
  ///
  /// Called ONLY when the user just ticked the GitHub checkbox to `true`
  /// (see the `onChanged` callback in [_buildResources]). Never called on
  /// uncheck, and never short-circuited by [_ghScopeResults] — every call
  /// site is a fresh invocation of [_resolveCheckDeleteRepoScope], so two
  /// consecutive checkbox ticks always produce two calls (FR-006, no
  /// caching within the dialog session).
  ///
  /// - [GhScopeStatus.present]: the optimistic `_selectedResources.add`
  ///   already performed by the caller stays in place — no popup.
  /// - [GhScopeStatus.missing] / [GhScopeStatus.checkFailed] /
  ///   [GhScopeStatus.cliUnavailable]: the optimistic selection is rolled
  ///   back (checkbox returns to unchecked) and
  ///   [GithubPermissionPopup] is shown with the matching status. Tapping
  ///   its action button (only offered for missing/checkFailed) opens a
  ///   terminal via [_resolveOnOpenTerminalForGhScopeRefresh] and closes
  ///   the popup immediately (FR-011) — the checkbox is already unchecked
  ///   at that point, so no further state change is needed there.
  Future<void> _checkGithubScope(ExternalResource resource) async {
    _pendingScopeChecks.add(resource.uri);

    final GhScopeStatus status;
    try {
      status = await _resolveCheckDeleteRepoScope()();
    } finally {
      if (mounted) {
        setState(() => _pendingScopeChecks.remove(resource.uri));
      } else {
        _pendingScopeChecks.remove(resource.uri);
      }
    }

    if (!mounted) return;

    // Review fix (In-flight-Race Finding 1b): if the user already
    // unchecked this resource while the check was still running, their
    // decision already stands — a late popup (or a late result-map write)
    // would be misleading, so bail out before touching either.
    if (!_selectedResources.contains(resource.uri)) {
      return;
    }

    setState(() => _ghScopeResults[resource.uri] = status);

    if (status == GhScopeStatus.present) {
      return;
    }

    // Blocked (missing/checkFailed/cliUnavailable): roll back the
    // optimistic check so the checkbox reflects "not actively deletable
    // yet" (FR-005).
    setState(() => _selectedResources.remove(resource.uri));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => GithubPermissionPopup(
        status: status,
        onOpenTerminal: () {
          unawaited(_resolveOnOpenTerminalForGhScopeRefresh()());
        },
      ),
    );
  }

  GhScopeChecker _resolveCheckDeleteRepoScope() {
    return widget.checkDeleteRepoScope ??
        widget.ghDetectionService.checkDeleteRepoScope;
  }

  Future<void> Function() _resolveOnOpenTerminalForGhScopeRefresh() {
    return widget.onOpenTerminalForGhScopeRefresh ??
        QuickActionsService().openTerminalWithGhScopeRefresh;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _nameMatches => _textController.text == widget.project.displayName;

  /// Types flagged as destructive-external (Vercel/GitHub) require the
  /// additional "cannot be undone" confirmation step (FR-007) before any
  /// external deletion call is made. Claude memory (filesystem-only) and
  /// hint-only types (Figma/other, never actively deleted per FR-010) do
  /// not.
  bool _isDestructiveExternal(ExternalResourceType type) {
    switch (type) {
      case ExternalResourceType.vercel:
      case ExternalResourceType.github:
        return true;
      case ExternalResourceType.claudeMemory:
      case ExternalResourceType.figma:
      case ExternalResourceType.other:
        return false;
    }
  }

  bool get _hasCheckedDestructiveExternal {
    final resources = _resources;
    if (resources == null) return false;
    return resources.any(
      (r) =>
          _selectedResources.contains(r.uri) && _isDestructiveExternal(r.type),
    );
  }

  /// Entry point from the "Loeschen" button on the main form. Routes to
  /// the destructive-warning step (FR-007) when a checked resource is
  /// destructive-external; otherwise starts the flow directly (a
  /// Claude-memory-only or empty selection needs no extra warning). This
  /// is the ONLY path from [_DialogStep.form] — there is no other call
  /// site that starts the flow, so a destructive-external resource can
  /// never be deleted with just the project-name confirmation (SC-004).
  ///
  /// Review fix (In-flight-Race Finding 1a): also guarded on
  /// [_hasPendingScopeCheckForSelected] — the "Loeschen" button is
  /// disabled for the same condition in [_buildButtons], so this check is
  /// belt-and-suspenders in case the button is ever reached while
  /// technically still enabled (e.g. a race between rebuild and tap).
  void _onDeleteButtonPressed() {
    if (!_nameMatches ||
        _step != _DialogStep.form ||
        _hasPendingScopeCheckForSelected) {
      return;
    }

    if (_hasCheckedDestructiveExternal) {
      setState(() => _step = _DialogStep.destructiveWarning);
    } else {
      _startDeletionFlow();
    }
  }

  void _onDestructiveWarningBack() {
    setState(() => _step = _DialogStep.form);
  }

  void _onDestructiveWarningConfirmed() {
    _startDeletionFlow();
  }

  /// Starts the actual deletion. Once called, the step immediately becomes
  /// [_DialogStep.running] — the button is disabled, the close affordance
  /// is gone, and a second activation of either the main-form or
  /// destructive-warning button can no longer reach this method (both
  /// guard on `_step == _DialogStep.form` /
  /// `_step == _DialogStep.destructiveWarning`, which is no longer true)
  /// (FR-015/FR-016).
  ///
  /// The local folder/DB deletion ([deleteProject]) and the selected
  /// external-resource deletions ([deleteSelectedExternalResources]) are
  /// launched CONCURRENTLY and awaited together — one being slow or
  /// failing never delays or blocks the other (FR-008). Each external
  /// result flips its row from spinner to success/failure in place via
  /// [_externalResults] as soon as it arrives, without waiting for the
  /// whole batch.
  Future<void> _startDeletionFlow() async {
    setState(() => _step = _DialogStep.running);

    final resources = _resources ?? const <ExternalResource>[];
    final selectedResources = resources
        .where((r) => _selectedResources.contains(r.uri))
        .toList();

    final localDeleteFuture = deleteProject(widget.project.path);
    final externalDeleteFuture = deleteSelectedExternalResources(
      selectedResources,
      ghRunner: widget.ghRunner,
      vercelRunner: widget.vercelRunner,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _externalResults[result.uri] = result);
      },
    );

    final results = await Future.wait([
      localDeleteFuture,
      externalDeleteFuture,
    ]);

    if (!mounted) return;

    final success = results[0] as bool;
    if (success) {
      ref.invalidate(projectsProvider);
    }

    setState(() {
      _localDeleteSucceeded = success;
      _step = _DialogStep.result;
    });
  }

  IconData _iconForType(ExternalResourceType type) {
    switch (type) {
      case ExternalResourceType.github:
        return Icons.code;
      case ExternalResourceType.vercel:
        return Icons.cloud_outlined;
      case ExternalResourceType.figma:
        return Icons.palette_outlined;
      case ExternalResourceType.claudeMemory:
        return Icons.psychology_outlined;
      case ExternalResourceType.other:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final Widget child;
    switch (_step) {
      case _DialogStep.form:
        child = _buildMainForm(colors);
      case _DialogStep.destructiveWarning:
        child = _buildDestructiveWarning(colors);
      case _DialogStep.running:
      case _DialogStep.result:
        child = _buildResultContainer(colors);
    }

    return GlassDialog(maxWidth: 440, child: child);
  }

  Widget _buildMainForm(AppColors colors) {
    final hasResources = _resources != null && _resources!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(colors),
        const SizedBox(height: 16),
        _buildWarning(colors),
        if (hasResources) ...[
          const SizedBox(height: 16),
          _buildResources(colors),
        ],
        const SizedBox(height: 16),
        _buildProjectName(colors),
        const SizedBox(height: 16),
        _buildTextField(colors),
        const SizedBox(height: 24),
        _buildButtons(colors),
      ],
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Projekt loeschen',
            style: TextStyle(
              color: colors.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.textDim, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
          splashRadius: 16,
          tooltip: 'Schliessen',
        ),
      ],
    );
  }

  Widget _buildWarning(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.shade700.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        'Der Projektordner wird in den Papierkorb verschoben. '
        'Du kannst ihn dort bei Bedarf wiederherstellen.',
        style: TextStyle(color: colors.textSec, fontSize: 13),
      ),
    );
  }

  Widget _buildResources(AppColors colors) {
    final resources = _resources!;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.textDim.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verknuepfte externe Ressourcen',
            style: TextStyle(
              color: colors.textSec,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Column(
                children: resources.map((resource) {
                  final isSelected = _selectedResources.contains(resource.uri);
                  final displayUri = resource.uri.length > 50
                      ? '${resource.uri.substring(0, 50)}…'
                      : resource.uri;
                  final canActivelyDelete = _isActivelyDeletable(resource);

                  // Variant A: a per-row status text distinguishes active
                  // deletion from hint-only, instead of a separate visual
                  // element (FR-003/FR-004/FR-005/FR-006).
                  final statusText = canActivelyDelete
                      ? (isSelected ? 'wird aktiv geloescht' : 'nur Hinweis')
                      : 'Token fehlt / nur Hinweis';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: canActivelyDelete
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  if (val == true) {
                                    setState(
                                      () =>
                                          _selectedResources.add(resource.uri),
                                    );
                                    // GitHub-repo checkboxes require a
                                    // brand-new delete_repo scope
                                    // pre-flight check on every tick to
                                    // `true` (Spec 008, FR-002/FR-003/
                                    // FR-006) — the optimistic add above
                                    // is rolled back inside
                                    // _checkGithubScope if the result is
                                    // not `present`. Other resource
                                    // types have no pre-flight step.
                                    if (resource.type ==
                                        ExternalResourceType.github) {
                                      unawaited(_checkGithubScope(resource));
                                    }
                                  } else {
                                    setState(
                                      () => _selectedResources.remove(
                                        resource.uri,
                                      ),
                                    );
                                  }
                                },
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.amber.shade600
                                      : colors.textDim,
                                  width: 1.5,
                                ),
                                activeColor: Colors.amber.shade600,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _iconForType(resource.type),
                        color: isSelected
                            ? Colors.amber.shade600
                            : colors.textDim,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource.label,
                              style: TextStyle(
                                color: colors.textPri,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              displayUri,
                              style: TextStyle(
                                color: colors.textDim,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: canActivelyDelete && isSelected
                                    ? Colors.amber.shade600
                                    : colors.textDim,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectName(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Projekt', style: TextStyle(color: colors.textDim, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          widget.project.displayName,
          style: TextStyle(
            color: colors.textPri,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(AppColors colors) {
    return TextField(
      controller: _textController,
      autofocus: true,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      cursorColor: Colors.red.shade400,
      decoration: InputDecoration(
        hintText: 'Projektname zur Bestaetigung eingeben',
        hintStyle: TextStyle(color: colors.textDim, fontSize: 14),
        filled: true,
        fillColor: colors.bgElev.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _nameMatches
                ? Colors.red.shade700.withValues(alpha: 0.7)
                : colors.textDim.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildButtons(AppColors colors) {
    // Once the button has been activated once, _step is no longer `form`
    // (it moves to destructiveWarning or straight to running), so this
    // button is disabled for the remainder of the flow — a second
    // activation cannot start a duplicate run (FR-016). Also disabled
    // while a GitHub scope check for a currently-selected resource is
    // still in flight (review fix — In-flight-Race Finding 1a): starting
    // the flow before the check settles would bypass the whole point of
    // the pre-flight check.
    final deleteEnabled =
        _nameMatches &&
        _step == _DialogStep.form &&
        !_hasPendingScopeCheckForSelected;

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: _step == _DialogStep.form
              ? () => Navigator.of(context).pop(false)
              : null,
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: deleteEnabled ? _onDeleteButtonPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            disabledBackgroundColor: colors.textDim.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.5),
          ),
          child: const Text('Loeschen'),
        ),
      ],
    );
  }

  /// Dedicated full-step "cannot be undone" screen (Variant A, FR-007).
  /// Shown only when a checked resource is destructive-external (see
  /// [_hasCheckedDestructiveExternal]); replaces the main form entirely
  /// rather than overlaying it. No close IconButton here either — the
  /// only ways out are the two explicit actions below.
  Widget _buildDestructiveWarning(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade400,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Endgueltige Loeschung bestaetigen',
                style: TextStyle(
                  color: colors.textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.shade700.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            'Diese Aktion kann NICHT rueckgaengig gemacht werden. Die '
            'ausgewaehlten externen Ressourcen (Vercel-Projekt und/oder '
            'GitHub-Repository) werden dauerhaft geloescht.',
            style: TextStyle(
              color: colors.textPri,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _onDestructiveWarningBack,
              style: TextButton.styleFrom(foregroundColor: colors.textSec),
              child: const Text('Zurueck'),
            ),
            FilledButton(
              onPressed: _onDestructiveWarningConfirmed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ja, endgueltig loeschen'),
            ),
          ],
        ),
      ],
    );
  }

  /// In-place transitioning result container (Variant A): a single list
  /// whose per-resource rows show an in-progress state while
  /// [_DialogStep.running] and flip to a success/failure icon in place as
  /// each [DeletionResult] arrives in [_externalResults] (Figma rows never
  /// receive a result — FR-010 — and stay on their static hint). Ends with
  /// an explicit "Schliessen" action that only appears once
  /// [_DialogStep.result] is reached, and never auto-closes (FR-018) — the
  /// dialog stays on this step until that button is tapped.
  Widget _buildResultContainer(AppColors colors) {
    final selectedList = _resources!
        .where((r) => _selectedResources.contains(r.uri))
        .toList();
    final isRunning = _step == _DialogStep.running;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            isRunning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _localDeleteSucceeded == false
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _localDeleteSucceeded == false
                        ? Colors.red.shade400
                        : Colors.green.shade400,
                    size: 22,
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRunning
                    ? 'Projekt wird geloescht…'
                    : (_localDeleteSucceeded == false
                          ? 'Projektordner konnte nicht geloescht werden'
                          : 'Projekt geloescht'),
                style: TextStyle(
                  color: colors.textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedList.isNotEmpty) ...[
          Text(
            isRunning
                ? 'Ausgewaehlte Ressourcen:'
                : 'Ergebnis der ausgewaehlten Ressourcen:',
            style: TextStyle(color: colors.textSec, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colors.bgElev.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.textDim.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: selectedList.map((resource) {
                // Figma (and any other permanently hint-only type) is
                // never dispatched to a runner (FR-010) — it always shows
                // its static hint, never a spinner or a result icon.
                final isDispatchable =
                    resource.type != ExternalResourceType.figma &&
                    resource.type != ExternalResourceType.other;
                final result = _externalResults[resource.uri];
                final pending = isDispatchable && isRunning && result == null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildResultRowIcon(
                        pending: pending,
                        result: result,
                        fallbackIcon: _iconForType(resource.type),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource.label,
                              style: TextStyle(
                                color: colors.textPri,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              resource.uri,
                              style: TextStyle(
                                color: colors.textDim,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              result?.reason ?? resource.hint,
                              style: TextStyle(
                                color: result == null
                                    ? colors.textDim
                                    : (result.succeeded
                                          ? Colors.green.shade400
                                          : Colors.red.shade400),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (!isRunning)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.textDim.withValues(alpha: 0.2),
                foregroundColor: colors.textPri,
              ),
              child: const Text('Schliessen'),
            ),
          ),
      ],
    );
  }

  /// The leading icon for one result row: a spinner while [pending], the
  /// resource-type icon while the row has no result yet and isn't
  /// dispatchable (Figma — always static), or a success/failure icon once
  /// [result] has arrived.
  Widget _buildResultRowIcon({
    required bool pending,
    required DeletionResult? result,
    required IconData fallbackIcon,
  }) {
    if (pending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.amber.shade600,
        ),
      );
    }
    if (result == null) {
      return Icon(fallbackIcon, color: Colors.amber.shade600, size: 16);
    }
    return Icon(
      result.succeeded ? Icons.check_circle : Icons.error_outline,
      color: result.succeeded ? Colors.green.shade400 : Colors.red.shade400,
      size: 16,
    );
  }
}
