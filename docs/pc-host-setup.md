# Setting up the gaming PC (Sunshine)

[Sunshine](https://github.com/LizardByte/Sunshine) is the open-source streaming
host Moonlight connects to. (NVIDIA's GameStream, which Moonlight was
originally built for, has been discontinued.)

## Install

- **Windows:** download the installer from the
  [Sunshine releases page](https://github.com/LizardByte/Sunshine/releases) or
  run `winget install LizardByte.Sunshine`. Let it install as a service so it
  starts at boot.
- **Linux:** see the
  [Sunshine docs](https://docs.lizardbyte.dev/projects/sunshine/latest/) for
  your distro (Flatpak, .deb, AUR, etc.).

Open the web UI at **<https://localhost:47990>** (accept the self-signed
certificate warning) and create the admin username and password.

## Recommended settings

In the web UI, under **Configuration**:

| Section | Setting | Value |
|---|---|---|
| Audio/Video | Encoder | Your GPU: NVENC (NVIDIA), AMF/VA-API (AMD), Quick Sync (Intel) |
| Advanced | HEVC Support | **Advertised** (the Pi 5 can only hardware-decode HEVC) |
| Network | UPnP | Off (only needed for streaming over the internet) |

Leave everything else at its default to start with.

## Firewall

The Windows installer opens the firewall ports itself. If you have a
third-party firewall, or if Moonlight can't find or pair with the PC, allow:

- TCP 47984, 47989, 47990, 48010
- UDP 47998–48000, 48002, 48010

## Network

- Connect the **PC by wire** too, if you can. Wi-Fi on either end adds jitter.
- Give the PC a fixed IP (a DHCP reservation in your router) so Moonlight
  always finds it.

## Wake-on-LAN (optional)

With Wake-on-LAN you can wake the PC from the couch: in Moonlight, select an
offline PC and choose **Wake PC**.

1. Enable Wake-on-LAN in the PC's BIOS/UEFI. It is often called "Power On By
   PCI-E" or "Wake on LAN".
2. Windows: Device Manager → your network adapter → Properties → **Power
   Management**: allow the device to wake the computer. Under **Advanced**,
   enable "Wake on Magic Packet".
3. Pair Moonlight while the PC is on. Moonlight remembers its MAC address for
   waking it later.

Wake-on-LAN generally only works when the PC is connected by Ethernet.

## Matching resolution to the TV

If the PC's monitor is 1440p or ultrawide and the TV is 16:9 1080p/4K, the
stream will be letterboxed or scaled. Options:

- **Simplest:** in Sunshine's **Applications** tab, add "Do" and "Undo"
  commands to the Desktop/Steam app that switch the PC's resolution, e.g. with
  [QRes](https://sourceforge.net/projects/qres/) or
  [MonitorSwitcher](https://sourceforge.net/projects/monitorswitcher/) on
  Windows.
- **Best:** use a virtual display, so the PC streams to a display that matches
  the client exactly and your real monitor can stay off:
  - [Apollo](https://github.com/ClassicOldSong/Apollo) is a Sunshine fork with
    a built-in virtual display that matches each Moonlight client's resolution
    automatically (Windows).
  - Or use [Virtual Display Driver](https://github.com/VirtualDrivers/Virtual-Display-Driver)
    with regular Sunshine.

## Apps

Sunshine ships with **Desktop** and **Steam Big Picture** entries. Big Picture
works well on a TV with a controller and launches every Steam game. You can add
other launchers (Xbox app, Playnite fullscreen, etc.) in the **Applications**
tab.
