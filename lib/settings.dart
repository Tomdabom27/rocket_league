import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const minJoystickScale = 0.6;
  static const maxJoystickScale = 1.4;

  static const _joystickKey = 'joystick_scale';

  SharedPreferences? _prefs;

  double _joystickScale = 1.0;
  double get joystickScale => _joystickScale;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = _prefs!.getDouble(_joystickKey);
      if (saved != null) {
        _joystickScale = saved
            .clamp(minJoystickScale, maxJoystickScale)
            .toDouble();
      }
    } catch (_) {}
  }

  void setJoystickScale(double value) {
    final v = value.clamp(minJoystickScale, maxJoystickScale).toDouble();
    if (v == _joystickScale) return;
    _joystickScale = v;
    notifyListeners();
  }

  Future<void> saveJoystickScale() async {
    try {
      await _prefs?.setDouble(_joystickKey, _joystickScale);
    } catch (_) {}
  }
}
