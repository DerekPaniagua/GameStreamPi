# GameStreamPi

Turn a Raspberry Pi 5 into a small game streaming box for your TV. Games run on
your gaming PC and stream to the Pi over your home network, and you play with an
Xbox controller.

```
┌──────────────────────┐   home network    ┌──────────────────┐   HDMI   ┌──────┐
│ Gaming PC            │ ────────────────▶ │ Raspberry Pi 5   │ ───────▶ │  TV  │
│ Sunshine (host)      │  HEVC video+audio │ Moonlight        │          └──────┘
│                      │ ◀──────────────── │ (boots straight  │
└──────────────────────┘   controller input│  into it)        │ ◀── Xbox controller
                                           └──────────────────┘     (BT / USB / dongle)
```

- **[Sunshine](https://github.com/LizardByte/Sunshine)** runs on the PC. It
  captures the game and encodes it with your GPU.
- **[Moonlight](https://moonlight-stream.org/)** runs on the Pi. It decodes the
  stream in hardware and sends controller input back to the PC.

This repo sets up the Pi. One script installs Moonlight and the controller
drivers and makes the Pi boot straight into Moonlight on the TV, like a
console. It also applies a few tweaks to make streaming smoother.

## What you need

| Item | Notes |
|---|---|
| Raspberry Pi 5 (8 GB is plenty) | |
| **Active cooler** or a fan case | Streaming is a sustained load, and a hot Pi slows itself down and stutters |
| Official 27W USB-C power supply | Weaker supplies cause under-voltage throttling |
| microSD card (16 GB+) or NVMe | |
| Micro-HDMI to HDMI cable | Use the HDMI port next to the USB-C power port (HDMI0) |
| **Wired Ethernet** (strongly recommended) | 5 GHz Wi-Fi can work. Wired Ethernet is the biggest single factor in how smooth the stream feels |
| Xbox controller | Bluetooth (Xbox One S and newer), USB cable, or the Xbox Wireless Adapter |
| Gaming PC | Windows or Linux, with a GPU that can encode HEVC (NVIDIA GTX 950+, AMD RX 400+, Intel 6th gen+) |

> **Why HEVC?** The Pi 5 has a hardware decoder for HEVC (H.265) but **not**
> for H.264. Stream in HEVC or the Pi will decode in software and stutter.

## Setup

### 1. Set up the PC

Follow [docs/pc-host-setup.md](docs/pc-host-setup.md) to install and configure
Sunshine. It takes about 10 minutes.

### 2. Flash the Pi

In [Raspberry Pi Imager](https://www.raspberrypi.com/software/):

1. Choose **Raspberry Pi OS Lite (64-bit)**. Use the Lite version, because no
   desktop is needed.
2. Open the settings (the gear icon or "Edit settings"):
   - Set a hostname, e.g. `gamestreampi`
   - Set a username and password
   - **Enable SSH**
   - Configure Wi-Fi if you're not using Ethernet
3. Flash, insert the card, connect the Pi to the TV and network, and power on.

### 3. Install

SSH in from your computer:

```bash
ssh <user>@gamestreampi.local

# Update first. A kernel update needs a reboot before the drivers can build.
sudo apt update && sudo apt full-upgrade -y && sudo reboot
```

After the reboot, SSH in again and run:

```bash
sudo apt install -y git
git clone <this-repo-url> GameStreamPi
cd GameStreamPi
sudo ./pi/install.sh --force-1080p
sudo reboot
```

Installer options:

| Flag | Effect |
|---|---|
| `--force-1080p` | Sets the Pi's HDMI output to 1080p60. Recommended if your TV is 4K and you stream at 1080p, because it avoids scaling and keeps the Pi's display pipeline light. Leave it off if you want to stream at 4K. |
| `--xone` | Installs the driver for the **Xbox Wireless Adapter** USB dongle. Not needed for Bluetooth or a USB cable. |
| `--no-autostart` | Don't boot into Moonlight. |
| `--no-perf` | Leave the CPU on its default power-saving governor. |

### 4. Pair a controller

Turn the controller on, then hold its pair button (top edge, next to the USB
port) until the Xbox logo flashes rapidly. The Pi pairs it automatically
within a few seconds, and the logo stays lit when it's connected. After that
the controller reconnects on its own whenever you turn it on.

To keep Bluetooth scanning from adding lag or slowing Wi-Fi, the Pi only looks
for new controllers while **no** controller is connected. To add a second
controller, turn the first one off (hold the Xbox button for about 6 seconds),
pair the new one, then turn the first one back on.

If pairing doesn't work, run `gamestreampi pair-controller` over SSH while you
pair. It shows what the pairing service is doing.

**USB cable:** just plug it in, no pairing needed.
**Xbox Wireless Adapter:** plug in the dongle (installed with `--xone`), then
press the pair buttons on the dongle and on the controller.

### 5. Pair Moonlight with your PC

On the TV, Moonlight should show your PC (if it doesn't, use **Add PC** with the
PC's IP address). Select the PC, and Moonlight shows a PIN. On the PC, open
Sunshine's web UI at <https://localhost:47990>, go to **PIN**, and enter it.

### 6. Recommended Moonlight settings

Open **Settings** (gear icon) in Moonlight on the TV:

| Setting | Value |
|---|---|
| Resolution | 1080p (try 4K once 1080p is smooth) |
| Frame rate | 60 FPS |
| Video bitrate | 20–30 Mbps wired, 15–20 Mbps on Wi-Fi |
| Video codec | **HEVC (H.265)** |
| Video decoder | Force hardware decoding |
| Frame pacing | On (smoother, at the cost of a little latency) |
| Optimize game settings | On |
| Mute host PC speakers while streaming | On |
| Quit app on PC after quitting session | Your preference |

Press **Start + Select + L1 + R1** (Menu + View + LB + RB on Xbox) during a
stream to end it, and **Select + L1 + R1 + X** to show the performance
overlay. The overlay is the best way to see whether stutter comes from the
network or the decoder.

## Daily use

Turn on the Pi and the controller, pick your PC, and pick a game. To run the
helper commands, SSH in:

```
gamestreampi status          # Moonlight, controllers, network, temperature, throttling
gamestreampi pair-controller # watch the auto-pairing service while pairing
gamestreampi restart         # restart Moonlight on the TV
gamestreampi kiosk off       # stop auto-launching Moonlight; the TV shows a shell
gamestreampi kiosk on        # go back to boot-to-Moonlight
gamestreampi logs            # last Moonlight log
```

If you have no SSH access, press **Ctrl+Alt+F2** on a USB keyboard to get a
login prompt on a second console.

## What the installer changes

- Installs `moonlight-qt` from Moonlight's official Raspberry Pi repository.
  This build renders straight to the display (KMS/DRM) without a desktop.
- Installs [xpadneo](https://github.com/atar-axis/xpadneo) (Bluetooth Xbox
  controllers: correct mapping, rumble, battery) and optionally
  [xone](https://github.com/dlundqvist/xone) (wireless adapter), both through DKMS.
  DKMS rebuilds them automatically after kernel updates.
- Bluetooth: enables fast reconnects and automatic re-pairing, and runs
  `gamestreampi-autopair.service`, which pairs any Xbox controller put into
  pairing mode while no controller is connected.
- Disables Wi-Fi power saving, which causes latency spikes.
- Pins the CPU governor to `performance` (`gamestreampi-cpu-performance.service`).
- Adds `consoleblank=0` (and optionally the 1080p mode) to `/boot/firmware/cmdline.txt`.
- Sets up console autologin on tty1 and adds a hook to your shell profile that
  launches Moonlight. If Moonlight exits or crashes, it relaunches.
- Adds `/usr/local/bin/gamestreampi` and `/usr/local/bin/gamestreampi-launch`.

Re-running the installer is safe, because each step skips itself if it was
already done.

## More

- [docs/pc-host-setup.md](docs/pc-host-setup.md): Sunshine setup, Wake-on-LAN,
  matching the PC's resolution to the TV
- [docs/troubleshooting.md](docs/troubleshooting.md): stutter, controllers,
  audio, black screens
