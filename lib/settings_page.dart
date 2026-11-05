import 'package:flutter/material.dart';

import 'settings.dart';
import 'ui_kit.dart';

class SettingsPill extends StatelessWidget {
  const SettingsPill({super.key});

  @override
  Widget build(BuildContext context) {
    return TopPill(
      label: 'SETTINGS',
      icon: LucideShape.settings,
      iconSize: 24,
      iconLeft: 14,
      textLeft: 52,
      width: 200,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'SETTINGS',
      pill: TopPill(
        label: 'BACK',
        icon: LucideShape.chevronLeft,
        iconSize: 38,
        iconLeft: 4,
        textLeft: 53,
        onTap: () => Navigator.of(context).pop(),
      ),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final s = DesignScale.of(context);
    final settings = AppSettings.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scale = settings.joystickScale;
        final hint = AppText.body(s * 0.8, color: const Color(0x99FFFFFF));

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 48 * s),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'JOYSTICK SIZE',
                          style: AppText.body(s, color: Colors.white),
                        ),
                        Text(
                          '${(scale * 100).round()}%',
                          style: AppText.body(s, color: AppColors.mint),
                        ),
                      ],
                    ),
                    SizedBox(height: 12 * s),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8 * s,
                        trackShape: const RoundedRectSliderTrackShape(),
                        activeTrackColor: AppColors.blue,
                        inactiveTrackColor: AppColors.overlayOuter,
                        thumbColor: AppColors.light,
                        overlayColor: AppColors.blueTrack,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 14 * s,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 26 * s,
                        ),
                      ),
                      child: Slider(
                        value: scale,
                        min: AppSettings.minJoystickScale,
                        max: AppSettings.maxJoystickScale,
                        onChanged: settings.setJoystickScale,
                        onChangeEnd: (_) => settings.saveJoystickScale(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6 * s),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('SMALL', style: hint),
                          Text('LARGE', style: hint),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 48 * s),
              _Preview(scale: scale),
            ],
          ),
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = DesignScale.of(context);
    final slot = 300 * s;
    final base = 210 * s * scale;
    final knob = base * 129 / 210;

    return SizedBox(
      width: slot,
      height: slot,
      child: Center(
        child: Container(
          width: base,
          height: base,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.overlayOuter,
          ),
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.overlayInner,
            ),
          ),
        ),
      ),
    );
  }
}
