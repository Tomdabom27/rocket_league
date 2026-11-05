import 'dart:async';

import 'package:bluetooth_serial_android/bluetooth_serial_android.dart';
import 'package:flutter/foundation.dart';

class CarProtocol {
  static String drive(int left, int right, bool boosting) {
    int boostValue;
    if (boosting) {
      boostValue = 1;
    } else {
      boostValue = 0;
    }
    return 'L:$left,R:$right,B:$boostValue\n';
  }
}

class FoundDevice {
  const FoundDevice({required this.name, required this.address});

  final String name;
  final String address;

  String get id => address;

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

class CarLink extends ChangeNotifier {
  CarLink._();
  static final CarLink instance = CarLink._();

  static const _sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

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

  Future<void> stopScanning() async {}

  Future<void> loadDevices() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      await FlutterBluetoothSerial.ensurePermissions();
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

  Future<String?> connect(FoundDevice found) async {
    _connectingAddress = found.address;
    notifyListeners();
    try {
      final ok = await FlutterBluetoothSerial.connect(
        found.address,
        uuid: _sppUuid,
        timeoutMs: 5000,
      );
      _connected = ok;
      if (ok) {
        _lastL = 0;
        _lastR = 0;
        _startKeepAlive();
        _write(CarProtocol.drive(0, 0, false));
      }
      return ok ? null : 'COULDN’T CONNECT';
    } catch (_) {
      _connected = false;
      _stopKeepAlive();
      return 'COULDN’T CONNECT';
    } finally {
      _connectingAddress = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _stopKeepAlive();
    try {
      await FlutterBluetoothSerial.write(CarProtocol.drive(0, 0, false));
    } catch (_) {}
    try {
      await FlutterBluetoothSerial.disconnect();
    } catch (_) {}
    _connected = false;
    notifyListeners();
  }

  Timer? _keepAlive;

  void _startKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_connected) return;
      _write(CarProtocol.drive(_lastL, _lastR, _boosting));
    });
  }

  void _stopKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = null;
  }

  static const normalMax = 150;
  static const boostMax = 255;

  double _x = 0;
  double _y = 0;
  bool _boosting = false;
  int _lastL = 0;
  int _lastR = 0;
  DateTime _lastDriveAt = DateTime.fromMillisecondsSinceEpoch(0);

  void sendDrive(double x, double y) {
    _x = x;
    _y = y;
    _sendMixed();
  }

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

    _lastL = il;
    _lastR = ir;

    final stop = il == 0 && ir == 0;
    final now = DateTime.now();
    if (!force &&
        !stop &&
        now.difference(_lastDriveAt) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastDriveAt = now;
    _write(CarProtocol.drive(il, ir, _boosting));
  }

  Future<void> _write(String message) async {
    if (!_connected) return;
    try {
      await FlutterBluetoothSerial.write(message);
    } catch (_) {
      _connected = false;
      _stopKeepAlive();
      notifyListeners();
    }
  }
}
