import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/deletion_service.dart';
import 'package:pro_orc/data/services/resource_detector.dart';
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
class DeleteProjectDialog extends ConsumerStatefulWidget {
  const DeleteProjectDialog({
    super.key,
    required this.project,
  });

  final ProjectModel project;

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

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() => setState(() {}));
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final resources = await detectExternalResources(widget.project);
      if (mounted) setState(() => _resources = resources);
    } catch (_) {
      if (mounted) setState(() => _resources = []);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _nameMatches =>
      _textController.text == widget.project.displayName;

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
      child: _showSummary
          ? _buildSummary(colors)
          : _buildMainForm(colors),
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
        style: TextStyle(
          color: colors.textSec,
          fontSize: 13,
        ),
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

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
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
                        ),
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
                            if (isSelected)
                              Text(
                                resource.hint,
                                style: TextStyle(
                                  color: Colors.amber.shade600,
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
        Text(
          'Projekt',
          style: TextStyle(color: colors.textDim, fontSize: 12),
        ),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildButtons(AppColors colors) {
    final deleteEnabled = _nameMatches && !_isDeleting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
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
            Icon(Icons.check_circle_outline,
                color: Colors.green.shade400, size: 22),
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
