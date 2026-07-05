import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pro_orc/features/shell/shell_screen.dart';
import 'package:pro_orc/theme/app_theme.dart';
import 'package:pro_orc/window/activation_policy_service.dart';
import 'package:pro_orc/window/window_geometry_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  launchAtStartup.setup(
    appName: 'Pro Orc',
    appPath: Platform.resolvedExecutable,
  );

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
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

    await ActivationPolicyService().setRegular();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: ProOrcApp()));
}

class ProOrcApp extends StatelessWidget {
  const ProOrcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Orc',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ShellScreen(),
    );
  }
}
