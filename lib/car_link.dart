import 'dart:async';

import 'package:bluetooth_serial_android/bluetooth_serial_android.dart';
import 'package:flutter/foundation.dart';

class CarProtocol {
  /// [left] / [right] are motor values in -255..255.
  /// Trailing "B:1"/"B:0" marks whether boost is active — your current
  /// sketch ignores it (toInt() stops at the first non-digit character),
  /// so this is safe to add before any LED code exists.
  static String drive(int left, int right, bool boosting) =>
      'L: $left,R: $right B:${boosting ? 1 : 0}\n';
}

class FoundDevice {
  const FoundDevice({required this.name, required this.address});

  final String name;
  final String address;

  String get id => address;

  /// True when the paired device's name looks like a Bluetooth module
  /// rather than a phone, headphones, etc.
  bool get isModule {
    final n = name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    const hints = [
      'jdy',
      'hm10',
      'hmsoft',
      'bt05',
      'at09',
      'cc41',
      'hc05',
      'hc06',
      'hc08',
    ];
    return hints.any(n.contains);
  }
}

/// Single shared connection to the car. Screens listen to it.
class CarLink extends ChangeNotifier {
  CarLink._();
  static final CarLink instance = CarLink._();

  static const _sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  // ---- state ---------------------------------------------------------------

  List<FoundDevice> _devices = const [];
  List<FoundDevice> get devices => _devices;

  bool _loading = true;
  bool get loading => _loading;

  String? _loadError;
  String? get loadError => _loadError;

  String? _connectingAddress;
  String? get connectingId => _connectingAddress;

  bool _connected = false;
  bool get isConnected => _connected;

  StreamSubscription<dynamic>? _scanSub;

  Future<void> stopScanning() async {
    try {
      await FlutterBluetoothSerial.cancelDiscovery();
    } catch (_) {}
  }

  // ---- loading paired + nearby devices --------------------------------

  /// Lists paired devices that are also currently in range (i.e. turned on
  /// and discoverable nearby), the same set Android's own Bluetooth
  /// settings screen marks as "available".
  Future<void> loadDevices() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      await FlutterBluetoothSerial.ensurePermissions();
      await stopScanning();

      final paired = await FlutterBluetoothSerial.getPairedDevices();
      final pairedByAddress = <String, String>{
        for (final d in paired)
          if (d['address'] is String)
            d['address'] as String: (d['name'] ?? 'UNKNOWN DEVICE'),
      };

      final nearby = await FlutterBluetoothSerial.scanDevices();

      _devices =
          nearby
              .map((d) => d['address'])
              .whereType<String>()
              .where(pairedByAddress.containsKey)
              .toSet()
              .map((a) => FoundDevice(name: pairedByAddress[a]!, address: a))
              .toList()
            ..sort((a, b) {
              if (a.isModule != b.isModule) return a.isModule ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
    } catch (_) {
      _loadError = 'COULDN’T SCAN FOR DEVICES';
    }
    _loading = false;
    notifyListeners();
  }

  // ---- connecting ------------------------------------------------------

  /// Returns null on success, otherwise a short message to show the user.
  Future<String?> connect(FoundDevice found) async {
    _connectingAddress = found.address;
    _connected = false;
    notifyListeners();

    try {
      await stopScanning();
      try {
        await FlutterBluetoothSerial.disconnect();
      } catch (_) {}

      final ok = await FlutterBluetoothSerial.connect(
        found.address,
        uuid: _sppUuid,
        timeoutMs: 15000,
      );
      _connected = ok;
      return ok ? null : 'COULDN’T CONNECT';
    } catch (_) {
      _connected = false;
      return 'COULDN’T CONNECT';
    } finally {
      _connectingAddress = null;
      notifyListeners();
    }
  }

  /// Drops the connection (the "unpair" of the BACK button).
  Future<void> disconnect() async {
    try {
      await FlutterBluetoothSerial.disconnect();
    } catch (_) {}
    _connected = false;
    notifyListeners();
  }

  // ---- sending -----------------------------------------------------------

  /// Motor limit while not boosting / while boosting (max 255).
  static const normalMax = 150;
  static const boostMax = 255;

  double _x = 0;
  double _y = 0;
  bool _boosting = false;
  int _lastL = 0;
  int _lastR = 0;
  DateTime _lastDriveAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// [x] and [y] are -1..1, y positive = forward.
  void sendDrive(double x, double y) {
    _x = x;
    _y = y;
    _sendMixed();
  }

  /// Lifts / restores the speed cap and re-sends the current stick position
  /// immediately.
  void setBoosting(bool on) {
    _boosting = on;
    _sendMixed(force: true);
  }

  void _sendMixed({bool force = false}) {
    final l = _y + _x;
    final r = _y - _x;
    final m = (l.abs() > r.abs() ? l.abs() : r.abs()).clamp(
      1.0,
      double.infinity,
    );
    final limit = _boosting ? boostMax : normalMax;
    final il = (l / m * limit).round();
    final ir = (r / m * limit).round();

    if (!force && il == _lastL && ir == _lastR) return;
    final stop = il == 0 && ir == 0;
    final now = DateTime.now();
    if (!force &&
        !stop &&
        now.difference(_lastDriveAt) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastL = il;
    _lastR = ir;
    _lastDriveAt = now;
    _write(CarProtocol.drive(il, ir, _boosting));
  }

  Future<void> _write(String message) async {
    if (!_connected) return; // skipped / not connected: silently do nothing
    try {
      await FlutterBluetoothSerial.write(message);
    } catch (_) {
      _connected = false;
      notifyListeners();
    }
  }
}
