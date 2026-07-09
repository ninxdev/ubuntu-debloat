#!/usr/bin/env bash
#
# Pure vanilla GNOME 50 on Ubuntu 26.04 LTS (Server install)
# Minimal, no Ubuntu session / Yaru theme / Ubuntu extensions / Snap.
# Run as:  sudo bash pure-gnome-26.04.sh
#
set -euo pipefail

# Re-exec as root if needed
if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package lists"
apt-get update

# ---------------------------------------------------------------------------
# 1. Install PURE GNOME core with --no-install-recommends.
#    This is the key step: Ubuntu's gnome-shell/gdm3 *Recommend* ubuntu-session
#    (the Ubuntu skin). Skipping recommends keeps the vanilla GNOME session.
# ---------------------------------------------------------------------------
echo "==> Installing gnome-core (vanilla GNOME, no recommends)"
apt-get install -y --no-install-recommends gnome-core

# Protect the real GNOME core so autoremove can never delete it later
apt-mark manual \
  gnome-shell gdm3 gnome-control-center gnome-session nautilus \
  gnome-settings-daemon gnome-keyring gnome-menus gnome-backgrounds \
  gsettings-desktop-schemas adwaita-icon-theme gnome-snapshot ghostty \
  network-manager pipewire-audio xdg-desktop-portal-gnome \
  libpam-gnome-keyring gnome-online-accounts

# ---------------------------------------------------------------------------
# 2. Networking: NetworkManager is what upstream GNOME expects.
# ---------------------------------------------------------------------------
echo "==> Installing NetworkManager"
apt-get install -y network-manager

echo "==> Setting netplan renderer to NetworkManager"
apt-get install -y python3-yaml
for f in /etc/netplan/*.yaml; do
  case "$f" in
    *.orig|*curtin*) continue ;;
  esac
  python3 - "$f" <<'PY'
import sys, yaml
f = sys.argv[1]
try:
    with open(f) as fh:
        data = yaml.safe_load(fh)
except Exception as e:
    print("skip", f, e); sys.exit(0)
if isinstance(data, dict) and isinstance(data.get('network'), dict):
    data['network']['renderer'] = 'NetworkManager'
    with open(f, 'w') as fh:
        yaml.safe_dump(data, fh, default_flow_style=False, sort_keys=False)
    print("updated", f)
PY
done
netplan apply

# ---------------------------------------------------------------------------
# 3. Terminal: ghostty only. Remove ptyxis (GNOME's default) and any stray
#    terminal, then register ghostty as the system terminal.
# ---------------------------------------------------------------------------
echo "==> Setting up ghostty as the only terminal"
apt-get install -y ghostty
apt-get remove -y --purge ptyxis 2>/dev/null || true
apt-get remove -y --purge alacritty xterm gnome-terminal 2>/dev/null || true
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ghostty 50
update-alternatives --set x-terminal-emulator /usr/bin/ghostty

# ---------------------------------------------------------------------------
# 4. Remove the optional GNOME apps (keep shell/session/gdm/control-center/
#    nautilus/snapshot/camera). Also drop the GNOME Software store.
# ---------------------------------------------------------------------------
echo "==> Removing optional GNOME apps (bloat)"
apt-get remove -y --purge \
  gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts \
  gnome-disk-utility gnome-font-viewer gnome-logs gnome-maps gnome-weather \
  gnome-sushi gnome-system-monitor gnome-text-editor baobab loupe papers \
  showtime simple-scan gnome-connections gnome-bluetooth-sendto gnome-user-docs \
  yelp ubuntu-wallpapers ubuntu-wallpapers-resolute tecla orca gnome-software

# ---------------------------------------------------------------------------
# 5. Pin everything we don't want, so apt upgrade can NEVER reinstall it.
# ---------------------------------------------------------------------------
echo "==> Writing apt pins (Priority -1 = never install)"
cat > /etc/apt/preferences.d/block-gnome-bloat <<'EOF'
# Pure-GNOME pins: block Ubuntu skin, Snap, and removed bloat apps/terminals.
Package: gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts gnome-disk-utility gnome-font-viewer gnome-logs gnome-maps gnome-weather gnome-sushi gnome-system-monitor gnome-text-editor baobab loupe papers showtime simple-scan gnome-connections gnome-bluetooth-sendto gnome-user-docs yelp ubuntu-wallpapers ubuntu-wallpapers-resolute tecla orca gnome-software snapd ubuntu-session gnome-shell-ubuntu-extensions yaru-theme-gnome-shell yaru-theme-gtk yaru-theme-icon yaru-theme-sound gsettings-ubuntu-schemas alacritty xterm gnome-terminal vim vim-common vim-runtime vim-tiny
Pin: release *
Pin-Priority: -1
EOF

# Also make sure snapd is gone (Server doesn't ship it, but be safe)
apt-get remove -y --purge snapd 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. Drop the gnome-core metapackage wrapper (core pkgs are marked manual).
# ---------------------------------------------------------------------------
apt-get remove -y gnome-core 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Reclaim the ~512 MB the kernel reserves for the crash dump.
# ---------------------------------------------------------------------------
echo "==> Freeing crashkernel reserved memory"
apt-get remove -y --purge kdump-tools 2>/dev/null || true
rm -f /etc/default/grub.d/kdump-tools.cfg
update-grub

# ---------------------------------------------------------------------------
# 8. Extras this user wants: htop, Google Chrome (comment out if unwanted).
# ---------------------------------------------------------------------------
apt-get install -y htop wget

if command -v wget >/dev/null; then
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg 2>/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list
  apt-get update
  apt-get install -y google-chrome-stable || echo "Chrome install failed (continuing)"
fi

# ---------------------------------------------------------------------------
# 9. Clean up orphans (core is protected by apt-mark manual above).
# ---------------------------------------------------------------------------
apt-get autoremove -y --purge

# ---------------------------------------------------------------------------
# 10. Make GDM the display manager and boot into the graphical target.
# ---------------------------------------------------------------------------
systemctl enable gdm3
systemctl set-default graphical.target
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager

echo
echo "DONE. Pure GNOME is installed. At the GDM login, only the vanilla"
echo "'GNOME' session is available (no Ubuntu session exists)."
echo "Reboot now:  sudo reboot"
