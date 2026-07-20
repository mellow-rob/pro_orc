import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/deletion_service.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/data/services/resource_detector.dart';
import 'package:pro_orc/data/services/vercel_detection_service.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// GitHub-style deletion confirmation dialog with external resource detection.
///
/// Requires the user to type the exact project name before enabling
/// the "Loeschen" button — prevents accidental permanent deletion.
///
/// On confirm: calls [deleteProject], invalidates [projectsProvider]
/// for auto-refresh. If resources were selected, shows a post-deletion
/// summary with cleanup hints before closing. Otherwise pops immediately.
/// On cancel: pops with `false` — no side effects.
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
  });

  final ProjectModel project;
  final VercelDetectionService vercelDetectionService;
  final GhDetectionService ghDetectionService;

  @override
  ConsumerState<DeleteProjectDialog> createState() =>
      _DeleteProjectDialogState();
}

class _DeleteProjectDialogState extends ConsumerState<DeleteProjectDialog> {
  late final TextEditingController _textController;
  bool _isDeleting = false;

  /// null = still loading, empty = none found
  List<ExternalResource>? _resources;

  /// URIs of resources the user wants to clean up (unchecked by default)
  final Set<String> _selectedResources = {};

  /// true after deletion — shows cleanup summary instead of the main form
  bool _showSummary = false;

  /// null = still resolving availability, true/false = resolved.
  /// Gates whether Vercel/GitHub resources render an active-delete
  /// checkbox (FR-003/FR-004/FR-006) — never gated on a stored token
  /// (FR-013).
  bool? _vercelAvailable;
  bool? _ghAvailable;

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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _nameMatches => _textController.text == widget.project.displayName;

  Future<void> _onDelete() async {
    if (!_nameMatches || _isDeleting) return;
    setState(() => _isDeleting = true);

    final success = await deleteProject(widget.project.path);

    if (!mounted) return;

    if (!success) {
      setState(() => _isDeleting = false);
      return;
    }

    ref.invalidate(projectsProvider);

    // If any resources were selected, show the summary screen
    if (_selectedResources.isNotEmpty) {
      setState(() => _showSummary = true);
    } else {
      Navigator.of(context).pop(true);
    }
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

    return GlassDialog(
      maxWidth: 440,
      child: _showSummary ? _buildSummary(colors) : _buildMainForm(colors),
    );
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
                                  setState(() {
                                    if (val == true) {
                                      _selectedResources.add(resource.uri);
                                    } else {
                                      _selectedResources.remove(resource.uri);
                                    }
                                  });
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
    final deleteEnabled = _nameMatches && !_isDeleting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isDeleting
              ? null
              : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: deleteEnabled ? _onDelete : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            disabledBackgroundColor: colors.textDim.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.5),
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Loeschen'),
        ),
      ],
    );
  }

  Widget _buildSummary(AppColors colors) {
    final selectedList = _resources!
        .where((r) => _selectedResources.contains(r.uri))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green.shade400,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Projekt geloescht',
              style: TextStyle(
                color: colors.textPri,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Folgende Ressourcen muessen manuell bereinigt werden:',
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconForType(resource.type),
                      color: Colors.amber.shade600,
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
                            resource.hint,
                            style: TextStyle(
                              color: colors.textDim,
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
}
