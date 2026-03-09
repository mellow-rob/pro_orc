import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Step 1: Claude Code CLI detection with install help.
///
/// Shows whether Claude Code is installed on the system, and if not,
/// provides installation instructions. Also includes an autostart toggle.
class ClaudeCheckStep extends StatelessWidget {
  const ClaudeCheckStep({
    super.key,
    required this.isInstalled,
    this.version,
    required this.onRecheck,
    required this.autostart,
    required this.onAutostartChanged,
  });

  final bool isInstalled;
  final String? version;
  final VoidCallback onRecheck;
  final bool autostart;
  final ValueChanged<bool> onAutostartChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(
          LucideIcons.terminal,
          size: 48,
          color: colors.cyan.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          'Claude Code CLI',
          style: TextStyle(
            color: colors.textPri,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        if (isInstalled) _buildInstalledState(colors) else _buildNotInstalledState(context, colors),
        const Spacer(),
        _buildAutostartToggle(colors),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInstalledState(AppColors colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.circleCheck, color: colors.emerald, size: 20),
              const SizedBox(width: 8),
              Text(
                'Claude Code ist installiert',
                style: TextStyle(color: colors.emerald, fontSize: 14),
              ),
            ],
          ),
        ),
        if (version != null) ...[
          const SizedBox(height: 8),
          Text(
            'Version: $version',
            style: TextStyle(color: colors.textDim, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildNotInstalledState(BuildContext context, AppColors colors) {
    const installCommand = 'npm install -g @anthropic-ai/claude-code';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.info, color: colors.amber, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Claude Code ist ein KI-Assistent fuer die Kommandozeile.',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Installation: anthropic.com/claude-code',
          style: TextStyle(color: colors.textDim, fontSize: 12),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: installCommand));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Befehl kopiert'),
                duration: const Duration(seconds: 2),
                backgroundColor: colors.bgElev,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.bgElev.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    installCommand,
                    style: TextStyle(
                      color: colors.textSec,
                      fontSize: 12,
                      fontFamily: 'SF Mono',
                    ),
                  ),
                ),
                Icon(LucideIcons.copy, size: 14, color: colors.textDim),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRecheck,
          icon: Icon(LucideIcons.refreshCw, size: 14, color: colors.cyan),
          label: Text(
            'Erneut pruefen',
            style: TextStyle(color: colors.cyan, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildAutostartToggle(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            'Beim Login starten',
            style: TextStyle(color: colors.textSec, fontSize: 13),
          ),
          const Spacer(),
          Switch.adaptive(
            value: autostart,
            onChanged: onAutostartChanged,
            activeTrackColor: colors.cyan,
          ),
        ],
      ),
    );
  }
}
