import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/gitignore_template.dart';
import 'package:pro_orc/features/shared/create_project/form_fields.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Animated switcher between the Code-tab and Research-tab toggle groups
/// for [CreateProjectDialog].
class TogglesSection extends StatelessWidget {
  const TogglesSection({
    super.key,
    required this.isCode,
    required this.colors,
    required this.accent,
    // Code toggles
    required this.gitInit,
    required this.onGitInitChanged,
    required this.claudeMd,
    required this.onClaudeMdChanged,
    required this.gitignoreTemplate,
    required this.onGitignoreTemplateChanged,
    required this.terminal,
    required this.onTerminalChanged,
    required this.codeRemSleep,
    required this.onCodeRemSleepChanged,
    // Research toggles
    required this.researchTerminal,
    required this.onResearchTerminalChanged,
    required this.researchRemSleep,
    required this.onResearchRemSleepChanged,
  });

  final bool isCode;
  final AppColors colors;
  final Color accent;

  final bool gitInit;
  final ValueChanged<bool> onGitInitChanged;
  final bool claudeMd;
  final ValueChanged<bool> onClaudeMdChanged;
  final GitignoreTemplate gitignoreTemplate;
  final ValueChanged<GitignoreTemplate> onGitignoreTemplateChanged;
  final bool terminal;
  final ValueChanged<bool> onTerminalChanged;
  final bool codeRemSleep;
  final ValueChanged<bool> onCodeRemSleepChanged;

  final bool researchTerminal;
  final ValueChanged<bool> onResearchTerminalChanged;
  final bool researchRemSleep;
  final ValueChanged<bool> onResearchRemSleepChanged;

  @override
  Widget build(BuildContext context) {
    final codeToggles = Column(
      key: const ValueKey('code-toggles'),
      children: [
        DialogToggleRow(
          colors: colors,
          title: 'Git Repository initialisieren',
          value: gitInit,
          onChanged: onGitInitChanged,
        ),
        DialogToggleRow(
          colors: colors,
          title: 'CLAUDE.md erstellen',
          value: claudeMd,
          onChanged: onClaudeMdChanged,
        ),
        _GitignoreDropdown(
          colors: colors,
          accent: accent,
          value: gitignoreTemplate,
          onChanged: onGitignoreTemplateChanged,
        ),
        DialogToggleRow(
          colors: colors,
          title: 'Terminal oeffnen',
          value: terminal,
          onChanged: onTerminalChanged,
        ),
        DialogToggleRow(
          colors: colors,
          title: 'rem-sleep nach Erstellung',
          value: codeRemSleep,
          onChanged: onCodeRemSleepChanged,
        ),
      ],
    );

    final researchToggles = Column(
      key: const ValueKey('research-toggles'),
      children: [
        DialogToggleRow(
          colors: colors,
          title: 'Terminal oeffnen',
          value: researchTerminal,
          onChanged: onResearchTerminalChanged,
        ),
        DialogToggleRow(
          colors: colors,
          title: 'rem-sleep nach Erstellung',
          value: researchRemSleep,
          onChanged: onResearchRemSleepChanged,
        ),
      ],
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isCode ? codeToggles : researchToggles,
      ),
    );
  }
}

class _GitignoreDropdown extends StatelessWidget {
  const _GitignoreDropdown({
    required this.colors,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final AppColors colors;
  final Color accent;
  final GitignoreTemplate value;
  final ValueChanged<GitignoreTemplate> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DropdownButtonFormField<GitignoreTemplate>(
        initialValue: value,
        dropdownColor: colors.bgElev,
        style: TextStyle(color: colors.textPri, fontSize: 13),
        iconEnabledColor: colors.textDim,
        isExpanded: true,
        decoration: colors.glassInputDecoration(
          labelText: '.gitignore Template',
          accentColor: accent,
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(
            value: GitignoreTemplate.none,
            child: Text('Kein .gitignore'),
          ),
          DropdownMenuItem(
            value: GitignoreTemplate.flutter,
            child: Text('Flutter'),
          ),
          DropdownMenuItem(
            value: GitignoreTemplate.nodejs,
            child: Text('Node.js'),
          ),
          DropdownMenuItem(
            value: GitignoreTemplate.nextjs,
            child: Text('HTML + Next.js'),
          ),
          DropdownMenuItem(
            value: GitignoreTemplate.python,
            child: Text('Python'),
          ),
          DropdownMenuItem(
            value: GitignoreTemplate.html,
            child: Text('HTML (statisch)'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
