#!/usr/bin/env bash
# GameStreamPi installer.
#
# Turns a fresh Raspberry Pi OS Lite (64-bit) install on a Raspberry Pi 5 into a
# boot-to-Moonlight game streaming box with Xbox controller support.
#
# Safe to re-run: every step checks whether it has already been done.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_XONE=0
FORCE_1080P=0
AUTOSTART=1
PERF=1

usage() {
  cat <<'EOF'
Usage: sudo ./pi/install.sh [options]

Options:
  --xone           Also install the xone driver for the official Xbox Wireless
                   Adapter (USB dongle). Not needed for Bluetooth or USB cable.
  --force-1080p    Force the HDMI output to 1920x1080@60 instead of the TV's
                   native mode. Recommended on 4K TVs when streaming at 1080p.
  --no-autostart   Don't boot straight into Moonlight.
  --no-perf        Don't pin the CPU governor to "performance".
  -h, --help       Show this help.
EOF
}

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --xone)         WITH_XONE=1 ;;
    --force-1080p)  FORCE_1080P=1 ;;
    --no-autostart) AUTOSTART=0 ;;
    --no-perf)      PERF=0 ;;
    -h|--help)      usage; exit 0 ;;
    *)              usage; die "Unknown option: $1" ;;
  esac
  shift
done

# --- Preflight -----------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || die "Run this with sudo: sudo ./pi/install.sh"
TARGET_USER="${SUDO_USER:-}"
[ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ] \
  || die "Run this with sudo from your normal user account, not as root directly."
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

[ "$(uname -m)" = "aarch64" ] || die "A 64-bit OS is required (found $(uname -m))."

MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo unknown)"
case "$MODEL" in
  *"Raspberry Pi 5"*) ;;
  *) warn "This was built for a Raspberry Pi 5; detected '$MODEL'. Continuing anyway." ;;
esac

BOOT_DIR=/boot/firmware
[ -d "$BOOT_DIR" ] || BOOT_DIR=/boot
CMDLINE="$BOOT_DIR/cmdline.txt"

# --- Steps ---------------------------------------------------------------------

install_base_packages() {
  log "Installing base packages"
  apt-get update
  apt-get install -y --no-install-recommends \
    git curl ca-certificates lsb-release dkms bluez iw
}

install_moonlight() {
  if dpkg -s moonlight-qt >/dev/null 2>&1; then
    log "Moonlight already installed ($(dpkg-query -W -f='${Version}' moonlight-qt))"
    return
  fi
  log "Installing Moonlight (official Raspberry Pi build)"
  # The official repo is built for running directly on the console (KMS/DRM)
  # with hardware HEVC decoding, which is what we want for a kiosk-style box.
  local codename
  codename="$(lsb_release -cs)"
  curl -1sLf 'https://dl.cloudsmith.io/public/moonlight-game-streaming/moonlight-qt/setup.deb.sh' \
    | distro=raspbian codename="$codename" bash
  apt-get install -y moonlight-qt \
    || die "Couldn't install moonlight-qt. The Moonlight repo may not support '$codename' yet; see docs/troubleshooting.md."
}

install_kernel_headers() {
  local kver
  kver="$(uname -r)"
  if [ -e "/lib/modules/$kver/build" ]; then
    log "Kernel headers present for $kver"
    return
  fi
  log "Installing kernel headers for $kver"
  local pkg
  case "$kver" in
    *-rpi-2712) pkg=linux-headers-rpi-2712 ;;
    *-rpi-v8)   pkg=linux-headers-rpi-v8 ;;
    *)          pkg="linux-headers-$kver" ;;
  esac
  apt-get install -y "linux-headers-$kver" 2>/dev/null || apt-get install -y "$pkg"

  # If apt pulled in headers for a newer kernel than the one running, DKMS
  # can't build for the running kernel until we reboot into the new one.
  [ -e "/lib/modules/$kver/build" ] \
    || die "Headers for the running kernel ($kver) aren't available. Run 'sudo apt full-upgrade && sudo reboot', then re-run this script."
}

# Builds and installs a DKMS driver from a git repo using its own install script.
install_dkms_driver() {
  local name="$1" repo="$2"; shift 2
  if dkms status 2>/dev/null | grep -q "^$name"; then
    log "$name already installed"
    return
  fi
  log "Installing $name"
  local src="/usr/local/src/$name"
  rm -rf "$src"
  git clone --depth 1 "$repo" "$src"
  (cd "$src" && "$@")
}

install_xpadneo() {
  # xpadneo: proper Xbox controller support over Bluetooth (correct button
  # mapping, rumble, battery reporting). USB-cable controllers work out of the
  # box with the kernel's built-in xpad driver.
  install_dkms_driver hid-xpadneo https://github.com/atar-axis/xpadneo.git ./install.sh
}

install_xone() {
  # xone: driver for the official Xbox Wireless Adapter dongle. The original
  # medusalix/xone repo is unmaintained; this fork tracks newer kernels.
  install_dkms_driver xone https://github.com/dlundqvist/xone.git ./install.sh
  log "Downloading Xbox Wireless Adapter firmware"
  xone-get-firmware.sh --skip-disclaimer
}

# Sets "key = value" in a bluez config file, uncommenting the key if needed.
set_bluez_option() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^#?\s*$key\s*=" "$file"; then
    sed -i -E "s|^#?\s*$key\s*=.*|$key = $value|" "$file"
  else
    warn "$key not found in $file; skipping"
  fi
}

configure_bluetooth() {
  log "Configuring Bluetooth for controllers"
  local conf=/etc/bluetooth/main.conf
  # Faster reconnects when a controller wakes up.
  set_bluez_option "$conf" FastConnectable true
  # Let a controller that forgot its pairing re-pair without manual cleanup.
  set_bluez_option "$conf" JustWorksRepairing always
  set_bluez_option "$conf" AutoEnable true
  systemctl enable bluetooth
  systemctl restart bluetooth
}

configure_wifi_powersave() {
  # Wi-Fi power saving adds latency spikes that show up as stutter.
  if [ -d /etc/NetworkManager/conf.d ]; then
    log "Disabling Wi-Fi power saving"
    printf '[connection]\nwifi.powersave = 2\n' \
      >/etc/NetworkManager/conf.d/gamestreampi-wifi-powersave.conf
  fi
}

configure_performance() {
  log "Pinning CPU governor to performance"
  install -m 644 "$REPO_DIR/systemd/gamestreampi-cpu-performance.service" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now gamestreampi-cpu-performance.service
}

add_cmdline_arg() {
  local arg="$1"
  grep -qF -- "$arg" "$CMDLINE" || sed -i "1 s|\$| $arg|" "$CMDLINE"
}

configure_display() {
  log "Configuring display"
  # Never blank the console; Moonlight's UI sits idle on it for long periods.
  add_cmdline_arg consoleblank=0
  if [ "$FORCE_1080P" -eq 1 ]; then
    if grep -q "video=HDMI-A-1:" "$CMDLINE"; then
      warn "An HDMI video mode is already set in $CMDLINE; leaving it alone."
    else
      add_cmdline_arg "video=HDMI-A-1:1920x1080@60"
    fi
  fi
}

install_helpers() {
  log "Installing helper commands"
  install -m 755 "$REPO_DIR/bin/gamestreampi" /usr/local/bin/gamestreampi
  install -m 755 "$REPO_DIR/bin/gamestreampi-launch" /usr/local/bin/gamestreampi-launch
  usermod -aG video,render,input,bluetooth "$TARGET_USER"
}

configure_autostart() {
  log "Configuring boot straight into Moonlight on $TARGET_USER's console"

  # Console autologin on tty1 (the same thing raspi-config's "B2" option does).
  mkdir -p /etc/systemd/system/getty@tty1.service.d
  cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $TARGET_USER --noclear %I \$TERM
EOF
  systemctl set-default multi-user.target
  systemctl daemon-reload

  # Bash only reads the first of these that exists, so hook whichever is used.
  local profile="$TARGET_HOME/.bash_profile"
  [ -f "$profile" ] || profile="$TARGET_HOME/.profile"
  if ! grep -q '>>> gamestreampi >>>' "$profile" 2>/dev/null; then
    cat >>"$profile" <<'EOF'

# >>> gamestreampi >>>
# Launch Moonlight full-screen when logging in on the TV (tty1), unless kiosk
# mode was turned off with `gamestreampi kiosk off`.
if [ "$(tty)" = /dev/tty1 ] && [ ! -e "$HOME/.config/gamestreampi/kiosk-off" ]; then
  exec /usr/local/bin/gamestreampi-launch
fi
# <<< gamestreampi <<<
EOF
    chown "$TARGET_USER:" "$profile"
  fi
}

# --- Main ----------------------------------------------------------------------

install_base_packages
install_moonlight
install_kernel_headers
install_xpadneo
[ "$WITH_XONE" -eq 1 ] && install_xone
configure_bluetooth
configure_wifi_powersave
[ "$PERF" -eq 1 ] && configure_performance
configure_display
install_helpers
[ "$AUTOSTART" -eq 1 ] && configure_autostart

log "Done!"
cat <<EOF

Next steps:
  1. Reboot:                 sudo reboot
  2. Pair a controller:      gamestreampi pair-controller   (over SSH)
  3. In Moonlight on the TV, select your PC and enter the PIN in Sunshine's
     web UI on the PC (https://localhost:47990).

See README.md for recommended Moonlight settings.
EOF
