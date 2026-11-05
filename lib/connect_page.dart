import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'car_link.dart';
import 'play_page.dart';
import 'settings_page.dart';
import 'ui_kit.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final link = CarLink.instance;

  @override
  void initState() {
    super.initState();
    link.loadDevices();
  }

  @override
  void dispose() {
    link.stopScanning();
    super.dispose();
  }

  Future<void> _connect(FoundDevice device) async {
    final error = await link.connect(device);
    if (!mounted) return;
    if (error != null) {
      _toast(error);
      return;
    }
    await _openPlay(skipped: false);
  }

  Future<void> _openPlay({required bool skipped}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PlayPage(skipped: skipped)));
    if (mounted) link.loadDevices();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: GoogleFonts.fredoka(
              fontSize: 16,
              letterSpacing: 1.6,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'CONNECT A DEVICE',
      pill: TopPill(
        label: 'SKIP',
        icon: LucideShape.skipForward,
        iconSize: 24,
        iconLeft: 14,
        textLeft: 61,
        onTap: () => _openPlay(skipped: true),
      ),
      trailing: const SettingsPill(),
      child: ListenableBuilder(
        listenable: link,
        builder: (context, _) => _DeviceBox(link: link, onConnect: _connect),
      ),
    );
  }
}

class _DeviceBox extends StatelessWidget {
  const _DeviceBox({required this.link, required this.onConnect});

  final CarLink link;
  final ValueChanged<FoundDevice> onConnect;

  @override
  Widget build(BuildContext context) {
    final s = DesignScale.of(context);
    return Column(
      children: [
        SizedBox(height: 22 * s),
        Text('NEARBY DEVICES', style: AppText.body(s, color: Colors.white)),
        Expanded(child: _content(s)),
      ],
    );
  }

  Widget _content(double s) {
    if (link.loading) return _Message('SCANNING…', s);
    if (link.loadError != null) return _Message(link.loadError!, s);
    if (link.devices.isEmpty) {
      return _Message('NO PAIRED DEVICES NEARBY', s);
    }

    final modules = link.devices.where((d) => d.isModule).toList();
    final others = link.devices.where((d) => !d.isModule).toList();
    final busy = link.connectingId != null;

    final children = <Widget>[];
    var needGap = false;

    void addRow(FoundDevice d) {
      if (needGap) children.add(SizedBox(height: 22 * s));
      children.add(
        _DeviceRow(
          device: d,
          connecting: link.connectingId == d.id,
          disabled: busy,
          onConnect: () => onConnect(d),
        ),
      );
      needGap = true;
    }

    modules.forEach(addRow);

    if (modules.isNotEmpty && others.isNotEmpty) {
      children
        ..add(SizedBox(height: 20 * s))
        ..add(Container(height: 1, color: Colors.white))
        ..add(SizedBox(height: 21 * s));
      needGap = false;
    }

    others.forEach(addRow);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 574 * s + 48 * s),
        child: ListView(
          padding: EdgeInsets.fromLTRB(24 * s, 32 * s, 24 * s, 24 * s),
          children: children,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, this.s);

  final String text;
  final double s;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * s),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.body(s, color: const Color(0x99FFFFFF)),
      ),
    ),
  );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.connecting,
    required this.disabled,
    required this.onConnect,
  });

  final FoundDevice device;
  final bool connecting;
  final bool disabled;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final s = DesignScale.of(context);
    return Container(
      height: 64 * s,
      padding: EdgeInsets.only(left: 16 * s, right: 11 * s),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(13 * s),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    device.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(s),
                  ),
                ),
                if (device.isModule) ...[
                  SizedBox(width: 18 * s),
                  Container(
                    width: 158 * s,
                    height: 43 * s,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(6 * s),
                    ),
                    child: Text('BT MODULE', style: AppText.body(s)),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8 * s),
          Material(
            color: AppColors.navy,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: disabled ? null : onConnect,
              child: SizedBox(
                width: 154 * s,
                height: 43 * s,
                child: Center(
                  child: connecting
                      ? SizedBox(
                          width: 20 * s,
                          height: 20 * s,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'CONNECT',
                          style: GoogleFonts.fredoka(
                            fontSize: 20 * s,
                            letterSpacing: 2 * s,
                            color: disabled
                                ? const Color(0x80FFFFFF)
                                : Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
