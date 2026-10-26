# Troubleshooting

Start with `gamestreampi status` over SSH, and turn on Moonlight's performance
overlay during a stream (**Select + L1 + R1 + X**, i.e. View + LB + RB + X on
an Xbox controller).

## Stutter or lag

Read the overlay:

| Overlay shows | Likely cause | Fix |
|---|---|---|
| High "frames dropped by your network connection" | Network | Use Ethernet on both ends. On Wi-Fi, use 5 GHz and lower the bitrate |
| High "average decoding time" (>10 ms) or the decoder isn't hardware | Software decoding | Set Moonlight's codec to **HEVC** and the decoder to hardware. Make sure Sunshine advertises HEVC |
| High "frames dropped due to jitter" | Frame pacing / display timing | Make sure Moonlight's FPS matches the TV refresh (60). Try toggling Frame pacing |
| High host processing latency | PC encoder | Make sure Sunshine uses the GPU encoder, not software |

Also check:

- `throttled=` in `gamestreampi status` should be `0x0`. Any other value means
  under-voltage (use the official 27W supply) or overheating (add a cooler).
- Turn on **Game Mode** in the TV's picture settings. Without it, many TVs add
  50–100 ms of processing delay.
- On a 4K TV streaming 1080p, re-run the installer with `--force-1080p`.

## Moonlight won't install ("repo may not support ...")

Moonlight's Raspberry Pi repo is published per Raspberry Pi OS release. If a
new OS release just came out, the repo may not have caught up yet. Check
<https://github.com/moonlight-stream/moonlight-docs/wiki/Installing-Moonlight-Qt-on-Raspberry-Pi-4>
for current instructions, or flash the previous Raspberry Pi OS release
("Raspberry Pi OS (Legacy)" in Imager).

## Controller

**Won't pair over Bluetooth**
- Update the controller's firmware with the Xbox Accessories app on a PC or
  Xbox. Old firmware is the most common cause.
- Make sure the logo is flashing *rapidly*, which means pairing mode. Slow
  flashing means it's trying to reconnect to its last device.
- Run `bluetoothctl devices` to see whether the Pi can see it at all.

**Pairs but buttons are wrong / no rumble**
- Check that xpadneo is loaded: `dkms status` should list `hid-xpadneo`, and
  `lsmod | grep xpadneo` should show it. If DKMS shows it isn't built for the
  current kernel (e.g. after an update), run
  `sudo apt install linux-headers-rpi-2712` and reboot.

**Disconnects or input lag over Bluetooth**
- The Pi's Wi-Fi and Bluetooth share a radio and antenna. Use Ethernet for the
  network, or use a USB cable or the Xbox Wireless Adapter for the controller.
- Keep line of sight to the Pi. Metal cases block the signal.

## No sound

Audio goes over HDMI to the TV. Make sure the cable is in **HDMI0** (the port
next to USB-C power). If you use HDMI1, check `aplay -l` and set the default
card in `/etc/asound.conf`.

## Black screen / no Moonlight on the TV

- Check `gamestreampi status`. If Moonlight isn't running, read
  `gamestreampi logs`.
- If kiosk mode was turned off, run `gamestreampi kiosk on`.
- Some TVs don't wake for an HDMI signal that started before they were on.
  Toggle the TV input or run `gamestreampi restart`.

## Getting a shell on the TV

`gamestreampi kiosk off` over SSH, or press **Ctrl+Alt+F2** on a USB keyboard.
