import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/agent_detail_content.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/mcp_server_detail_content.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/plugin_detail_content.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/skill_detail_content.dart';

// ---------------------------------------------------------------------------
// Public show functions
// ---------------------------------------------------------------------------

/// Opens a detail panel for a [SkillData] item.
Future<void> showSkillDetail(BuildContext context, SkillData skill) =>
    _showClaudeToolDetail(context, SkillDetailContent(skill: skill));

/// Opens a detail panel for a [PluginData] item.
Future<void> showPluginDetail(BuildContext context, PluginData plugin) =>
    _showClaudeToolDetail(context, PluginDetailContent(plugin: plugin));

/// Opens a detail panel for a [McpServerData] item.
Future<void> showMcpServerDetail(BuildContext context, McpServerData server) =>
    _showClaudeToolDetail(context, McpServerDetailContent(server: server));

/// Opens a detail panel for an [AgentData] item.
Future<void> showAgentDetail(BuildContext context, AgentData agent) =>
    _showClaudeToolDetail(context, AgentDetailContent(agent: agent));

// ---------------------------------------------------------------------------
// Shared dialog launcher
// ---------------------------------------------------------------------------

Future<void> _showClaudeToolDetail(BuildContext context, Widget content) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => content,
  );
}
