import 'dart:developer' as developer;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'package:pro_orc/data/services/claude_detection_service.dart';
import 'package:pro_orc/features/onboarding/steps/claude_check_step.dart';
import 'package:pro_orc/features/onboarding/steps/project_preview_step.dart';
import 'package:pro_orc/features/onboarding/steps/scan_dirs_step.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// 3-step onboarding wizard shown on first launch.
///
/// Steps:
/// 1. Claude Code CLI detection + autostart toggle
/// 2. Scan directory selection (folder picker)
/// 3. Project preview (read-only list of discovered projects)
///
/// The wizard persists scan directories to the database before
/// calling [onComplete]. All steps are skippable via 'Ueberspringen'.
class OnboardingWizard extends ConsumerStatefulWidget {
  const OnboardingWizard({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends ConsumerState<OnboardingWizard> {
  static const _totalSteps = 3;

  final _pageController = PageController();
  final _detectionService = const ClaudeDetectionService();

  int _currentStep = 0;
  bool _claudeInstalled = false;
  String? _claudeVersion;
  List<String> _scanDirs = [];
  bool _autostart = false;
  List<String> _projectNames = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkClaude();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkClaude() async {
    final installed = await _detectionService.isClaudeInstalled();
    String? version;
    if (installed) {
      version = await _detectionService.getClaudeVersion();
    }
    if (mounted) {
      setState(() {
        _claudeInstalled = installed;
        _claudeVersion = version;
      });
    }
  }

  Future<void> _addScanDir() async {
    final dir = await getDirectoryPath();
    if (dir != null && !_scanDirs.contains(dir)) {
      setState(() {
        _scanDirs = [..._scanDirs, dir];
      });
    }
  }

  void _removeScanDir(int index) {
    setState(() {
      _scanDirs = [
        ..._scanDirs.sublist(0, index),
        ..._scanDirs.sublist(index + 1),
      ];
    });
  }

  Future<void> _scanProjects() async {
    if (_scanDirs.isEmpty) {
      setState(() {
        _projectNames = [];
        _isScanning = false;
      });
      return;
    }

    setState(() => _isScanning = true);

    try {
      final db = ref.read(appDatabaseProvider);
      // Temporarily save dirs to scan, then use ProjectScanner
      await db.setScanDirs(_scanDirs);
      final scanner = ref.read(projectScannerProvider);
      final projects = await scanner.scanAll();
      if (mounted) {
        setState(() {
          _projectNames = projects.map((p) => p.displayName).toList();
          _isScanning = false;
        });
      }
    } catch (e) {
      developer.log(
        'Failed to scan projects during onboarding: $e',
        name: 'onboarding_wizard',
      );
      if (mounted) {
        setState(() {
          _projectNames = [];
          _isScanning = false;
        });
      }
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Trigger project scan when entering preview step
    if (step == 2) {
      _scanProjects();
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finishWizard();
    }
  }

  Future<void> _skipWizard() async {
    await _finishWizard();
  }

  Future<void> _finishWizard() async {
    final db = ref.read(appDatabaseProvider);
    if (_scanDirs.isNotEmpty) {
      await db.setScanDirs(_scanDirs);
    }

    // Handle autostart preference
    try {
      if (_autostart) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (e) {
      // launch_at_startup may fail in debug mode
      developer.log(
        'Failed to set launchAtStartup (autostart=$_autostart): $e',
        name: 'onboarding_wizard',
      );
    }

    widget.onComplete();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GlassDialog(
      maxWidth: 500,
      child: SizedBox(
        height: 460,
        child: Column(
          children: [
            _buildDotIndicator(colors),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: [
                  ClaudeCheckStep(
                    isInstalled: _claudeInstalled,
                    version: _claudeVersion,
                    onRecheck: _checkClaude,
                    autostart: _autostart,
                    onAutostartChanged: (value) {
                      setState(() => _autostart = value);
                    },
                  ),
                  ScanDirsStep(
                    scanDirs: _scanDirs,
                    onAddDir: _addScanDir,
                    onRemoveDir: _removeScanDir,
                  ),
                  ProjectPreviewStep(
                    projectNames: _projectNames,
                    isScanning: _isScanning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildBottomButtons(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildDotIndicator(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (index) {
        final isActive = index == _currentStep;
        return Container(
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? colors.cyan
                : colors.textDim.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildBottomButtons(AppColors colors) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _skipWizard,
          child: Text(
            'Ueberspringen',
            style: TextStyle(color: colors.textDim, fontSize: 13),
          ),
        ),
        Row(
          children: [
            if (_currentStep > 0)
              TextButton(
                onPressed: () => _goToStep(_currentStep - 1),
                child: Text(
                  'Zurueck',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: colors.bgBase,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: Text(
                isLastStep ? 'Fertig' : 'Weiter',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
