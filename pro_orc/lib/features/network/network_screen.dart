import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/collaboration_graph.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/network_graph_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Opens the full multi-project collaboration network as a full-screen modal
/// (M7 AD-1: not a NavigationRail destination — reached from the AgentsTab so
/// the rail stays at its current destination count).
Future<void> showNetworkScreen(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Netzwerk',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    pageBuilder: (context, animation, secondaryAnimation) =>
        const NetworkScreen(),
  );
}

/// Full-screen view of the whole project collaboration network: every project
/// in the middle column, shared agents on the left, shared skills on the
/// right, with edges bridging projects that share an agent/skill.
///
/// Zoomable/pannable via [InteractiveViewer]. Hovering a node highlights its
/// edges (like the M4 mini-graph); tapping a project node opens its
/// [ProjectDetailPanel]. Read-only.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final graphAsync = ref.watch(networkGraphProvider);

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            children: [
              _buildHeader(context, colors),
              Expanded(
                child: graphAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: colors.cyan),
                  ),
                  error: (_, _) => Center(
                    child: Text(
                      'Netzwerk konnte nicht geladen werden',
                      style: TextStyle(color: colors.textSec),
                    ),
                  ),
                  data: (graph) => graph.isEmpty
                      ? _buildEmpty(colors)
                      : _NetworkCanvas(graph: graph, colors: colors),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Icon(LucideIcons.workflow100, color: colors.cyan, size: 20),
          const SizedBox(width: 12),
          Text(
            'Netzwerk',
            style: TextStyle(
              color: colors.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          _LegendDot(color: colors.cyan, label: 'Projekt', colors: colors),
          const SizedBox(width: 12),
          _LegendDot(color: colors.violet, label: 'Agent', colors: colors),
          const SizedBox(width: 12),
          _LegendDot(color: colors.amber, label: 'Skill', colors: colors),
          const Spacer(),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(LucideIcons.x100, color: colors.textDim, size: 16),
              tooltip: 'Schliessen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Text(
        'Keine Projekte mit Agents oder Skills gefunden',
        style: TextStyle(color: colors.textDim, fontSize: 14),
      ),
    );
  }
}

/// Legend entry: a colored dot with a label.
class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.colors,
  });

  final Color color;
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: colors.textDim, fontSize: 11)),
      ],
    );
  }
}

/// Zoomable canvas that lays out the graph in three columns and draws edges +
/// node labels. Highlight state lives here so hovering a node repaints edges.
class _NetworkCanvas extends StatefulWidget {
  const _NetworkCanvas({required this.graph, required this.colors});

  final MultiCollaborationGraphData graph;
  final AppColors colors;

  @override
  State<_NetworkCanvas> createState() => _NetworkCanvasState();
}

class _NetworkCanvasState extends State<_NetworkCanvas> {
  String? _highlightedNodeId;

  @override
  Widget build(BuildContext context) {
    // Canvas height scales with the tallest column so many nodes stay legible;
    // the InteractiveViewer lets the user pan/zoom across it.
    final columnMax = [
      widget.graph.projectNodes.length,
      widget.graph.agentNodes.length,
      widget.graph.skillNodes.length,
    ].reduce((a, b) => a > b ? a : b);
    final canvasHeight = (columnMax * 46.0 + 80).clamp(360.0, 4000.0);

    return InteractiveViewer(
      minScale: 0.3,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(200),
      constrained: false,
      child: SizedBox(
        width: 900,
        height: canvasHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _NetworkLayout(
              graph: widget.graph,
              size: Size(constraints.maxWidth, canvasHeight),
            );

            return Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, canvasHeight),
                  painter: _NetworkPainter(
                    layout: layout,
                    colors: widget.colors,
                    highlightedNodeId: _highlightedNodeId,
                  ),
                ),
                for (final entry in layout.positions.entries)
                  Positioned(
                    left: entry.value.dx - 80,
                    top: entry.value.dy - 14,
                    width: 160,
                    child: _NetworkNodeLabel(
                      node: layout.nodeById[entry.key]!,
                      colors: widget.colors,
                      highlighted: _highlightedNodeId == entry.key,
                      onHover: (hovering) => setState(() {
                        _highlightedNodeId = hovering ? entry.key : null;
                      }),
                      onTap: () => _onNodeTap(layout.nodeById[entry.key]!),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onNodeTap(GraphNode node) {
    if (node.kind != GraphNodeKind.project) return;
    // Node id is `project:<folderId>` — strip the prefix to resolve the model.
    final folderId = node.id.substring('project:'.length);
    final container = ProviderScope.containerOf(context, listen: false);
    final project = container.read(projectByFolderIdProvider(folderId));
    if (project == null) return;
    showProjectDetail(context, project);
  }
}

/// Deterministic three-column layout: projects centered, agents left, skills
/// right, evenly spaced vertically within each column. Same column strategy as
/// the M4 mini-graph, scaled to all projects (M7 AD-2 — no force-directed).
class _NetworkLayout {
  _NetworkLayout({required this.graph, required this.size}) {
    _placeColumn(graph.agentNodes, size.width * 0.15);
    _placeColumn(graph.projectNodes, size.width * 0.5);
    _placeColumn(graph.skillNodes, size.width * 0.85);
  }

  final MultiCollaborationGraphData graph;
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

/// Draws each edge as a quadratic Bezier; edges touching the highlighted node
/// are drawn brighter and thicker.
class _NetworkPainter extends CustomPainter {
  _NetworkPainter({
    required this.layout,
    required this.colors,
    required this.highlightedNodeId,
  });

  final _NetworkLayout layout;
  final AppColors colors;
  final String? highlightedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in layout.graph.edges) {
      final from = layout.positions[edge.fromId];
      final to = layout.positions[edge.toId];
      if (from == null || to == null) continue;

      final isHighlighted =
          highlightedNodeId != null &&
          (edge.fromId == highlightedNodeId || edge.toId == highlightedNodeId);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.0 : 1.0
        ..color = (isHighlighted ? colors.cyan : colors.textDim).withValues(
          alpha: isHighlighted ? 0.8 : 0.18,
        );

      final midY = (from.dy + to.dy) / 2;
      final controlX = (from.dx + to.dx) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(controlX, midY, to.dx, to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_NetworkPainter oldDelegate) =>
      oldDelegate.highlightedNodeId != highlightedNodeId ||
      oldDelegate.layout != layout;
}

/// Node pill for the network canvas: colored dot by kind, hover to highlight,
/// tap (projects only) to open the detail panel.
class _NetworkNodeLabel extends StatelessWidget {
  const _NetworkNodeLabel({
    required this.node,
    required this.colors,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final GraphNode node;
  final AppColors colors;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  Color get _dotColor => switch (node.kind) {
    GraphNodeKind.project => colors.cyan,
    GraphNodeKind.agent => colors.violet,
    GraphNodeKind.skill => colors.amber,
  };

  @override
  Widget build(BuildContext context) {
    final isProject = node.kind == GraphNodeKind.project;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: isProject ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isProject ? onTap : null,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: highlighted
                  ? _dotColor.withValues(alpha: 0.15)
                  : colors.bgElev.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _dotColor.withValues(alpha: highlighted ? 0.7 : 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    node.label,
                    style: TextStyle(
                      color: highlighted ? _dotColor : colors.textSec,
                      fontSize: 11,
                      fontWeight: isProject ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
