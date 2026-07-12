import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pro_orc/window/activation_policy_service.dart';

class TrayService with TrayListener {
  TrayService({ActivationPolicyService? activationPolicyService})
    : _activationPolicyService =
          activationPolicyService ?? ActivationPolicyService();

  final ActivationPolicyService _activationPolicyService;

  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setIcon('assets/images/tray_icon.png');
    await trayManager.setToolTip('Pro Orc');
    final menu = Menu(
      items: [
        MenuItem(key: 'show_hide', label: 'Show/Hide Window'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    _toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_hide') {
      _toggleWindow();
    } else if (menuItem.key == 'quit') {
      windowManager.destroy();
    }
  }

  Future<void> _toggleWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
      await _activationPolicyService.setAccessory();
    } else {
      await _activationPolicyService.setRegular();
      await windowManager.show();
      await windowManager.focus();
    }
  }
}
