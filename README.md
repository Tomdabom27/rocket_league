# Rocket League RC Car

A Flutter app I made to drive my Rocket League style RC car from my phone. The UI is based on a Figma design I recreated. There's a screen to connect over Bluetooth, then a drive screen with a joystick, a boost button and a score.

The car itself is an Arduino Nano, a Bluetooth module, a motor driver and a little NeoPixel strip for lights.

Android only, because the Bluetooth package I used only works there.

## How it works

The app turns the joystick position into a left and right motor speed and sends it to the car as a line of text, like this:

```
L:150,R:-150,B:0
```

Left speed, right speed, and whether boost is on. Speeds go from -255 to 255 and negative means reverse. The line has to end with a newline or the Arduino just sits there waiting.

The app resends the current command every 100ms, because the car stops itself if it hasn't heard anything for 1.5 seconds. That way it doesn't drive off if my phone disconnects.

For the steering I mix the stick like this, where `x` is left/right, `y` is forward/back and `S` is the speed limit (150, or 255 when boosting):

```
left  = S * (y + x) / max(|y + x|, |y - x|, 1)
right = S * (y - x) / max(|y + x|, |y - x|, 1)
```

The divide at the end stops one wheel going over full power while keeping the turn the same shape.

## Wiring

- Left motor: speed on pin 5, direction on 4 and 2
- Right motor: speed on pin 6, direction on 9 and 10 (wired backwards, so the sketch flips it)
- NeoPixels on pin 12
- Bluetooth module on the RX/TX pins (0 and 1)
- Motor battery shares a ground with the Arduino

Unplug the Bluetooth module when uploading the sketch, otherwise uploads can fail.

## Running it

```
flutter pub get
flutter run
```

Pair the car's Bluetooth module in your phone's settings first, then open the app and pick it from the list.

## Bluetooth problems

This took me a while to figure out, so writing it down:

- The app uses `bluetooth_serial_android`, which only does classic Bluetooth. That works with HC-05, HC-06 and JDY-31 style modules. BLE-only modules like the JDY-08 won't connect with it, you'd need something like `flutter_blue_plus` instead.
- The baud rate in the Arduino sketch (9600) has to match the module. Some modules default to 115200.
- If it connects but nothing moves, check the motor battery is on and the grounds are joined.

## To do

- Settings