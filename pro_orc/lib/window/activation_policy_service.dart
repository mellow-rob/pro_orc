import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Switches the app's NSApplication activation policy between `.regular`
/// (Dock icon, Cmd+Tab, minimizable — used while the window is visible) and
/// `.accessory` (menubar-only, no Dock icon — used while the window is
/// hidden). Backed by a Swift MethodChannel in MainFlutterWindow.swift.
///
/// `LSUIElement=true` in Info.plist still governs the app's state at launch
/// (menubar-only by default); this service only changes behavior at runtime.
class ActivationPolicyService {
  const ActivationPolicyService();

  static const _channel = MethodChannel('pro_orc/activation_policy');

  /// Switches to `.regular`: shows a Dock icon and allows Cmd+Tab switching
  /// and window minimizing. Call this when the window becomes visible.
  Future<void> setRegular() async {
    try {
      await _channel.invokeMethod('setRegular');
    } catch (e) {
      developer.log('Failed to set regular activation policy: $e', name: 'activation_policy');
    }
  }

  /// Switches to `.accessory`: hides the Dock icon, menubar-only. Call this
  /// when the window is hidden.
  Future<void> setAccessory() async {
    try {
      await _channel.invokeMethod('setAccessory');
    } catch (e) {
      developer.log('Failed to set accessory activation policy: $e', name: 'activation_policy');
    }
  }
}
