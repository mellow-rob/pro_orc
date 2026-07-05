import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pro_orc/features/shell/shell_screen.dart';
import 'package:pro_orc/providers/theme_mode_provider.dart';
import 'package:pro_orc/theme/app_theme.dart';
import 'package:pro_orc/window/activation_policy_service.dart';
import 'package:pro_orc/window/window_geometry_service.dart';

/// Single shared instance, passed down to [ShellScreen] (which forwards it
/// to [TrayService]) so the whole app talks to the native activation-policy
/// MethodChannel through one object instead of ad-hoc `ActivationPolicyService()`
/// instances scattered across main.dart/shell_screen.dart/tray_service.dart.
/// Safe to share: the service is stateless, just a MethodChannel wrapper.
const _activationPolicyService = ActivationPolicyService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  launchAtStartup.setup(
    appName: 'Pro Orc',
    appPath: Platform.resolvedExecutable,
  );

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(680, 480),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();

    await windowManager.setPreventClose(true);

    final geometry = WindowGeometryService();
    final restored = await geometry.restore();
    if (!restored) {
      await windowManager.center();
    }

    await _activationPolicyService.setRegular();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: ProOrcApp()));
}

class ProOrcApp extends ConsumerWidget {
  const ProOrcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Pro Orc',
      debugShowCheckedModeBanner: false,
      theme: buildAppLightTheme(),
      darkTheme: buildAppTheme(),
      themeMode: themeMode,
      home: const ShellScreen(activationPolicyService: _activationPolicyService),
    );
  }
}
