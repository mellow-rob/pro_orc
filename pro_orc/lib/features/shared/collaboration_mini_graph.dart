import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/collaboration_graph.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Project-focused mini collaboration graph: the project node in the middle
/// column, its agents on the left, its skills on the right. Edges are drawn
/// as simple quadratic Bezier curves.
///
/// Read-only, no external graph package — a static column layout is enough
/// for the handful of nodes a single project has (typically well under 10).
/// Hover/tap on a node highlights its connected edges.
class CollaborationMiniGraph extends StatefulWidget {
  const CollaborationMiniGraph({
    super.key,
    required this.data,
    required this.colors,
    this.height = 220,
  });

  final CollaborationGraphData data;
  final AppColors colors;
  final double height;

  @override
  State<CollaborationMiniGraph> createState() => _CollaborationMiniGraphState();
}

class _CollaborationMiniGraphState extends State<CollaborationMiniGraph> {
  String? _highlightedNodeId;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _GraphLayout(
            data: widget.data,
            size: Size(constraints.maxWidth, widget.height),
          );

          return Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, widget.height),
                painter: _GraphPainter(
                  layout: layout,
                  colors: widget.colors,
                  highlightedNodeId: _highlightedNodeId,
                ),
              ),
              for (final positioned in layout.positions.entries)
                Positioned(
                  left: positioned.value.dx - 60,
                  top: positioned.value.dy - 14,
                  width: 120,
                  child: _NodeLabel(
                    node: layout.nodeById[positioned.key]!,
                    colors: widget.colors,
                    highlighted: _highlightedNodeId == positioned.key,
                    onHover: (hovering) => setState(() {
                      _highlightedNodeId = hovering ? positioned.key : null;
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Computes a static 3-column layout: project centered, agents left, skills
/// right, evenly spaced vertically within each column.
class _GraphLayout {
  _GraphLayout({required this.data, required this.size}) {
    nodeById[data.projectNode.id] = data.projectNode;
    positions[data.projectNode.id] = Offset(size.width / 2, size.height / 2);

    _placeColumn(data.agentNodes, size.width * 0.18);
    _placeColumn(data.skillNodes, size.width * 0.82);
  }

  final CollaborationGraphData data;
  final Size size;
  final Map<String, GraphNode> nodeById = {};
  final Map<String, Offset> positions = {};

  void _placeColumn(List<GraphNode> nodes, double x) {
    if (nodes.isEmpty) return;
    final step = size.height / (nodes.length + 1);
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      nodeById[node.id] = node;
      positions[node.id] = Offset(x, step * (i + 1));
    }
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.layout,
    required this.colors,
    required this.highlightedNodeId,
  });

  final _GraphLayout layout;
  final AppColors colors;
  final String? highlightedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    final projectPos = layout.positions[layout.data.projectNode.id]!;

    for (final edge in layout.data.edges) {
      final from = layout.positions[edge.fromId];
      final to = layout.positions[edge.toId];
      if (from == null || to == null) continue;

      final isHighlighted =
          highlightedNodeId != null && (edge.fromId == highlightedNodeId || edge.toId == highlightedNodeId);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.0 : 1.0
        ..color = (isHighlighted ? colors.cyan : colors.textDim)
            .withValues(alpha: isHighlighted ? 0.8 : 0.25);

      final controlX = (from.dx + to.dx) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(controlX, projectPos.dy, to.dx, to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.highlightedNodeId != highlightedNodeId || oldDelegate.layout != layout;
}

/// Small pill label for a single node, with a colored dot indicating kind
/// (project/agent/skill) and whether it is project-local.
class _NodeLabel extends StatelessWidget {
  const _NodeLabel({
    required this.node,
    required this.colors,
    required this.highlighted,
    required this.onHover,
  });

  final GraphNode node;
  final AppColors colors;
  final bool highlighted;
  final ValueChanged<bool> onHover;

  Color get _dotColor => switch (node.kind) {
        GraphNodeKind.project => colors.cyan,
        GraphNodeKind.agent => node.isLocal ? colors.violet : colors.textDim,
        GraphNodeKind.skill => colors.amber,
      };

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.click,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: highlighted
                ? _dotColor.withValues(alpha: 0.15)
                : colors.bgElev.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _dotColor.withValues(alpha: highlighted ? 0.6 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  node.label,
                  style: TextStyle(
                    color: highlighted ? _dotColor : colors.textSec,
                    fontSize: 11,
                    fontWeight: node.kind == GraphNodeKind.project
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
