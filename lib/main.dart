import 'package:bluetooth_serial_android/bluetooth_serial_android.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'connect_page.dart';
import 'ui_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterBluetoothSerial.ensurePermissions();
  runApp(const RocketLeagueApp());
}

class RocketLeagueApp extends StatelessWidget {
  const RocketLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rocket League Car',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.navy),
      ),
      builder: (context, child) {
        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        return Stack(
          children: [
            child!,
            if (portrait) const Positioned.fill(child: _RotatePrompt()),
          ],
        );
      },
      home: const ConnectPage(),
    );
  }
}

class _RotatePrompt extends StatelessWidget {
  const _RotatePrompt();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.screen_rotation_rounded,
              size: 72,
              color: AppColors.light,
            ),
            const SizedBox(height: 24),
            Text(
              'ROTATE YOUR SCREEN',
              style: GoogleFonts.fredoka(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
