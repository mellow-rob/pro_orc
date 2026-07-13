import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders the "DATEIEN" (.md file hierarchy) section body for
/// [ProjectDetailPanel] — a collapsible folder tree of [MdFileInfo].
class FilePreviewSection extends StatelessWidget {
  const FilePreviewSection({
    super.key,
    required this.mdFiles,
    required this.colors,
    required this.accent,
  });

  final List<MdFileInfo> mdFiles;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tree = _buildFileTree(mdFiles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Root-level files (no folder wrapper)
        for (final file in tree.files)
          _MdFileRow(file: file, depth: 0, colors: colors, accent: accent),
        // Root-level subdirectories
        for (final child in tree.children.entries)
          _FolderNode(
            name: child.key,
            node: child.value,
            depth: 0,
            colors: colors,
            accent: accent,
          ),
      ],
    );
  }
}

/// Tree node holding files at this directory level and child directories.
/// Immutable — built once by [_buildFileTree] via [_FileTreeNodeBuilder] and
/// consumed read-only by [_FolderNode].
class _FileTreeNode {
  const _FileTreeNode({required this.files, required this.children});

  final List<MdFileInfo> files;
  final Map<String, _FileTreeNode> children;
}

/// Mutable accumulator used only while assembling the tree in
/// [_buildFileTree] — never exposed outside that function.
class _FileTreeNodeBuilder {
  final List<MdFileInfo> files = [];
  final Map<String, _FileTreeNodeBuilder> children = {};

  _FileTreeNode toNode() {
    return _FileTreeNode(
      files: files,
      children: children.map((seg, child) => MapEntry(seg, child.toNode())),
    );
  }
}

/// Builds a nested tree from a flat list of [MdFileInfo].
_FileTreeNode _buildFileTree(List<MdFileInfo> files) {
  final root = _FileTreeNodeBuilder();
  for (final file in files) {
    final dir = p.dirname(file.relativePath);
    if (dir == '.') {
      root.files.add(file);
    } else {
      final segments = p.split(dir);
      var node = root;
      for (final seg in segments) {
        node = node.children.putIfAbsent(seg, _FileTreeNodeBuilder.new);
      }
      node.files.add(file);
    }
  }
  return root.toNode();
}

/// Collapsible folder node that renders its files and nested subfolders.
class _FolderNode extends StatefulWidget {
  const _FolderNode({
    required this.name,
    required this.node,
    required this.depth,
    required this.colors,
    required this.accent,
  });

  final String name;
  final _FileTreeNode node;
  final int depth;
  final AppColors colors;
  final Color accent;

  @override
  State<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends State<_FolderNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder header (clickable to toggle)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.only(left: indent),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? LucideIcons.chevronDown100
                          : LucideIcons.chevronRight100,
                      color: widget.colors.textDim,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? LucideIcons.folderOpen100
                          : LucideIcons.folder100,
                      color: widget.colors.textDim,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: widget.colors.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Expanded content: files then child folders
        if (_expanded) ...[
          for (final file in widget.node.files)
            _MdFileRow(
              file: file,
              depth: widget.depth + 1,
              colors: widget.colors,
              accent: widget.accent,
            ),
          for (final child in widget.node.children.entries)
            _FolderNode(
              name: child.key,
              node: child.value,
              depth: widget.depth + 1,
              colors: widget.colors,
              accent: widget.accent,
            ),
        ],
      ],
    );
  }
}

/// Clickable .md file row with hover accent and optional role label.
class _MdFileRow extends StatefulWidget {
  const _MdFileRow({
    required this.file,
    required this.depth,
    required this.colors,
    required this.accent,
  });

  final MdFileInfo file;
  final int depth;
  final AppColors colors;
  final Color accent;

  @override
  State<_MdFileRow> createState() => _MdFileRowState();
}

class _MdFileRowState extends State<_MdFileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent + 18),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () =>
              Process.run('open', [widget.file.path], runInShell: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText100,
                  color: _hovered ? widget.accent : widget.colors.textDim,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.file.name,
                    style: TextStyle(
                      color: _hovered ? widget.accent : widget.colors.textPri,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.file.role != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.file.role!,
                    style: TextStyle(
                      color: widget.colors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
