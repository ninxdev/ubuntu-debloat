#!/usr/bin/env bash
#
# debloat.sh  —  Pure vanilla GNOME 50 on Ubuntu 26.04 LTS (Server install)
# --------------------------------------------------------------------------
# Minimal, no Ubuntu session / Yaru theme / Ubuntu extensions / Snap.
# Run as:  sudo bash debloat.sh
#
# TARGET:  Ubuntu 26.04 LTS "Resolute Raccoon" Server (amd64) install.
# RESULT:  Vanilla GNOME 50 desktop, ghostty terminal, NetworkManager,
#          no Snap, no Ubuntu skin, no optional GNOME apps. GDM boots the
#          vanilla 'GNOME' session (no 'Ubuntu' session exists).
#
# ============================================================================
# WHY THIS ORDER (GDM enable BEFORE pinning, app removal LAST)
# ----------------------------------------------------------------------------
# The previous version of this script enabled GDM at the very end, AFTER the
# apt pin and autoremove. If anything went wrong during pinning or autoremove
# (and it did — see the ubuntu-wallpapers-resolute bug below), gdm3.service
# would be gone by the time `systemctl enable gdm3` ran, producing:
#     "Failed to enable unit: Unit gdm3.service does not exist"
#
# This version does, in order:
#   1. Install GNOME core + network + terminal
#   2. apt-mark manual EVERYTHING that must survive (so autoremove is safe)
#   3. Enable GDM + graphical.target  ← done EARLY, while gdm3 is fresh
#   4. Install user extras (htop, Chrome)
#   5. Remove kdump-tools (free 512 MB)
#   6. ONLY THEN remove optional GNOME apps and write apt pins
#   7. autoremove --purge as the very last step
#
# ============================================================================
# THE BUG THAT BROKE THE PREVIOUS SCRIPT (verified, see evidence at bottom)
# ----------------------------------------------------------------------------
# The previous script pinned `ubuntu-wallpapers-resolute` at Pin-Priority: -1
# and tried to `apt remove --purge ubuntu-wallpapers-resolute`. But:
#
#   gdm3  Depends  gnome-shell (>= 50~alpha)
#   gnome-shell  Depends  ubuntu-wallpapers                 <-- Ubuntu patch
#   ubuntu-wallpapers  Depends  ubuntu-wallpapers-resolute  <-- hard dep
#
# Pinning or removing `ubuntu-wallpapers-resolute` cascades through
# ubuntu-wallpapers -> gnome-shell -> gdm3 -> gnome-session, breaking GNOME.
# This is Ubuntu Bug 1894347 (open since 2020, still present in 26.04):
#   https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html
#   "Can't uninstall ubuntu-wallpapers and ubuntu-wallpapers-bionic
#    without gnome-shell"
#
# FIX: Do NOT pin or remove `ubuntu-wallpapers-resolute` (or `ubuntu-wallpapers`
# or `tecla`). Keep them. They are tiny relative to a working desktop.
# (ubuntu-wallpapers-resolute is ~63 MB of wallpaper data — acceptable cost.)
#
# ============================================================================
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
#    Skipping recommends is what avoids pulling in `ubuntu-session` (the
#    Ubuntu skin). The vanilla `gnome-session` is a hard dep of gnome-core
#    and WILL be installed — that's the session we want at the GDM login.
# ---------------------------------------------------------------------------
echo "==> Installing gnome-core (vanilla GNOME, no recommends)"
apt-get install -y --no-install-recommends gnome-core

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
# 3. Terminal: ghostty only. We register ghostty as the system terminal
#    NOW, but defer removal of ptyxis to the very end (section 11) so that
#    if anything earlier in the script breaks, we still have a working
#    terminal on the system.
# ---------------------------------------------------------------------------
echo "==> Installing ghostty and registering as default terminal"
apt-get install -y ghostty
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ghostty 50
update-alternatives --set x-terminal-emulator /usr/bin/ghostty

# ---------------------------------------------------------------------------
# 4. Protect EVERYTHING that must survive autoremove.
#
#    This list is the union of:
#      (a) GNOME core we explicitly want (gnome-shell, gdm3, etc.)
#      (b) hard deps of gdm3 / gnome-shell / gnome-control-center that the
#          PREVIOUS script forgot — these got purged by autoremove and
#          broke gdm3 (see screenshot):
#              gnome-session-common  (gdm3 hard-dep)
#              gnome-session-bin     (gdm3 hard-dep)
#              gnome-shell-common    (gnome-shell hard-dep)
#              mutter-common         (gnome-control-center hard-dep)
#              libgdm1               (gdm3 hard-dep)
#              gir1.2-gdm-1.0        (gnome-shell + gdm3 hard-dep)
#      (c) hard deps of gnome-shell that we cannot remove but the previous
#          script correctly did NOT pin (kept for clarity):
#              tecla                 (gnome-shell hard-dep)
#              ubuntu-wallpapers     (gnome-shell hard-dep)
#              ubuntu-wallpapers-resolute (ubuntu-wallpapers hard-dep)
#      (d) xdg-user-dirs-gtk — creates Desktop/Documents/Downloads/Music/
#          Pictures/Videos on first GNOME login. KEPT per user request.
#      (e) ubuntu-server metapackage + kernel metapackages — protect the
#          running kernel from autoremove (previous script's autoremove
#          purged linux-image-unsigned-7.0.0-14-generic, see screenshot).
# ---------------------------------------------------------------------------
echo "==> Marking critical packages as manually installed (protects autoremove)"
apt-mark manual \
  gnome-shell gdm3 gnome-control-center gnome-session nautilus \
  gnome-settings-daemon gnome-keyring gnome-menus gnome-backgrounds \
  gsettings-desktop-schemas adwaita-icon-theme gnome-snapshot gnome-bluetooth-sendto ghostty \
  network-manager pipewire-audio xdg-desktop-portal-gnome \
  libpam-gnome-keyring gnome-online-accounts xdg-user-dirs-gtk \
  gnome-session-common gnome-session-bin gnome-shell-common mutter-common \
  libgdm1 gir1.2-gdm-1.0 \
  tecla ubuntu-wallpapers ubuntu-wallpapers-resolute \
  ubuntu-server linux-image-generic linux-generic

# ---------------------------------------------------------------------------
# 5. Make GDM the display manager and boot into the graphical target.
#    DONE EARLY — while gdm3 is freshly installed and we KNOW it exists.
#    (This is the user's explicit request: GDM stuff BEFORE the apt pin.)
# ---------------------------------------------------------------------------
echo "==> Enabling GDM and graphical target"
systemctl enable gdm3
systemctl set-default graphical.target
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager

# ---------------------------------------------------------------------------
# 6. Extras: htop + Google Chrome (comment out the Chrome block if unwanted).
# ---------------------------------------------------------------------------
echo "==> Installing htop, wget"
apt-get install -y htop wget

if command -v wget >/dev/null; then
  echo "==> Adding Google Chrome repo (comment out this block to skip)"
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg 2>/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list
  apt-get update
  apt-get install -y google-chrome-stable || echo "Chrome install failed (continuing)"
fi

# ---------------------------------------------------------------------------
# 7. Free the ~512 MB the kernel reserves for crash dumps (kdump).
#    Safe to remove on a desktop; we have already protected the running
#    kernel metapackages with apt-mark manual above.
# ---------------------------------------------------------------------------
echo "==> Removing kdump-tools (frees ~512 MB reserved memory)"
apt-get remove -y --purge kdump-tools 2>/dev/null || true
rm -f /etc/default/grub.d/kdump-tools.cfg
update-grub

# ---------------------------------------------------------------------------
# 8. Drop the gnome-core metapackage wrapper.
#    All core pkgs we want are now marked manual (section 4), so dropping
#    the metapkg just makes the optional apps eligible for autoremove.
#    We do this BEFORE removing the optional apps so their removal doesn't
#    cascade back through gnome-core.
# ---------------------------------------------------------------------------
echo "==> Removing gnome-core metapackage (core pkgs are protected by apt-mark manual)"
apt-get remove -y gnome-core 2>/dev/null || true

# ---------------------------------------------------------------------------
# 9. Remove the optional GNOME apps (bloat).
#
#    VERIFIED SAFE-TO-REMOVE (none are hard deps of gnome-shell or gdm3):
#       gnome-calculator, gnome-calendar, gnome-characters, gnome-clocks,
#       gnome-contacts, gnome-disk-utility, gnome-font-viewer, gnome-logs,
#       gnome-maps, gnome-weather, gnome-sushi, gnome-system-monitor,
#       gnome-text-editor, baobab, loupe, papers, showtime, simple-scan,
#       gnome-connections, gnome-user-docs, yelp,
#       orca, gnome-software
#
#    The reverse-depends analysis (from Ubuntu 26.04 resolute Packages.gz)
#    shows each of these is ONLY hard-required-by metapackages that we are
#    also removing (gnome-core) or that aren't installed on Ubuntu Server
#    (cinnamon-desktop-environment, phosh-*, ubuntu-mate-*, etc.).
#
#    *** NOT IN THIS LIST (would break GNOME) ***
#       ubuntu-wallpapers-resolute  (hard dep of ubuntu-wallpapers -> gnome-shell)
#       ubuntu-wallpapers           (hard dep of gnome-shell)
#       tecla                       (hard dep of gnome-shell & gnome-control-center)
# ---------------------------------------------------------------------------
echo "==> Removing optional GNOME apps (bloat)"
apt-get remove -y --purge \
  gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts \
  gnome-disk-utility gnome-font-viewer gnome-logs gnome-maps gnome-weather \
  gnome-sushi gnome-system-monitor gnome-text-editor baobab loupe papers \
  showtime simple-scan gnome-connections gnome-user-docs \
  yelp orca gnome-software

# ---------------------------------------------------------------------------
# 10. Remove the default terminal (ptyxis) — we already registered ghostty.
#     Also remove any stray terminal that may have sneaked in.
# ---------------------------------------------------------------------------
echo "==> Removing ptyxis and stray terminals (ghostty is the only terminal)"
apt-get remove -y --purge ptyxis 2>/dev/null || true
apt-get remove -y --purge alacritty xterm gnome-terminal 2>/dev/null || true

# Also make sure snapd is gone (Server doesn't ship it, but ubuntu-server
# Recommends snapd, so it may be present).
echo "==> Removing snapd"
apt-get remove -y --purge snapd 2>/dev/null || true

# ---------------------------------------------------------------------------
# 11. Pin everything we don't want, so apt upgrade can NEVER reinstall it.
#
#     *** CRITICAL: do NOT pin the following (would break GNOME) ***
#        ubuntu-wallpapers-resolute   (hard dep of ubuntu-wallpapers)
#        ubuntu-wallpapers            (hard dep of gnome-shell)
#        tecla                        (hard dep of gnome-shell)
#        vim, vim-common, vim-runtime (hard dep of ubuntu-server)
#
#     `vim-tiny` is safe to pin (it's not a hard dep of anything we keep).
#
#     `ubuntu-session`, `gnome-shell-ubuntu-extensions`,
#     `yaru-theme-gnome-shell` are safe to pin: gdm3 lists them only as
#     one of several alternatives (`ubuntu-session | gnome-session | ...`)
#     and we have `gnome-session` installed, so the alternative is
#     satisfied without them.
# ---------------------------------------------------------------------------
echo "==> Writing apt pins (Priority -1 = never install)"
cat > /etc/apt/preferences.d/block-gnome-bloat <<'EOF'
# Pure-GNOME pins: block Ubuntu skin, Snap, removed bloat apps/terminals.
#
# DO NOT add to this list (would break GNOME, verified from Packages.gz):
#   ubuntu-wallpapers-resolute  (hard dep of ubuntu-wallpapers -> gnome-shell)
#   ubuntu-wallpapers           (hard dep of gnome-shell)
#   tecla                       (hard dep of gnome-shell & gnome-control-center)
#   vim, vim-common, vim-runtime  (hard dep of ubuntu-server)
Package: gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts gnome-disk-utility gnome-font-viewer gnome-logs gnome-maps gnome-weather gnome-sushi gnome-system-monitor gnome-text-editor baobab loupe papers showtime simple-scan gnome-connections gnome-user-docs yelp orca gnome-software snapd ubuntu-session gnome-shell-ubuntu-extensions yaru-theme-gnome-shell yaru-theme-gtk yaru-theme-icon yaru-theme-sound gsettings-ubuntu-schemas alacritty xterm gnome-terminal vim-tiny
Pin: release *
Pin-Priority: -1
EOF

# ---------------------------------------------------------------------------
# 12. Clean up orphans. This is now SAFE because everything we want is
#     marked manual in section 4 (including kernel metapackages and
#     gnome-session-common, gnome-session-bin, gnome-shell-common,
#     mutter-common, libgdm1, gir1.2-gdm-1.0).
# ---------------------------------------------------------------------------
echo "==> Autoremoving orphans (core is protected by apt-mark manual)"
apt-get autoremove -y --purge

# ---------------------------------------------------------------------------
# 13. Final sanity: verify gdm3 is still installed.
# ---------------------------------------------------------------------------
if ! systemctl list-unit-files gdm3.service --all 2>/dev/null | grep -q gdm3; then
  echo "!! WARNING: gdm3.service is missing — something went wrong."
  echo "!! Inspect /var/log/apt/history.log and rerun section 4-5."
  exit 1
fi

echo
echo "DONE. Pure vanilla GNOME 50 is installed."
echo "At the GDM login, only the vanilla 'GNOME' session is available"
echo "(no 'Ubuntu' session exists). Reboot now:  sudo reboot"
echo
echo "Optional GNOME apps were removed and pinned. Snap is gone."
echo "Ghostty is the only terminal. NetworkManager manages networking."
echo "Standard home folders (Desktop/Documents/Downloads/Music/Pictures/Videos)"
echo "will be created on first GNOME login by xdg-user-dirs-gtk."

# ============================================================================
# EVIDENCE & REFERENCES
# ----------------------------------------------------------------------------
# 1. Ubuntu Bug 1894347 — "Can't uninstall ubuntu-wallpapers and
#    ubuntu-wallpapers-bionic without gnome-shell" (open since 2020,
#    still present in 26.04 resolute). The exact same dependency chain
#    exists in 26.04: gnome-shell -> ubuntu-wallpapers -> -resolute.
#    https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html
#
# 2. Ubuntu 26.04 Packages.gz (amd64 main) — verified dependency chains:
#    http://archive.ubuntu.com/ubuntu/dists/resolute/main/binary-amd64/Packages.gz
#      gdm3 Depends: gnome-shell (>= 50~alpha)
#      gnome-shell Depends: ubuntu-wallpapers
#      ubuntu-wallpapers Depends: ubuntu-wallpapers-resolute
#      gdm3 Depends: gnome-session-bin (>= 50~alpha), gnome-session-common (>= 50~alpha),
#                    libgdm1 (= 50.0-0ubuntu1), gir1.2-gdm-1.0 (= 50.0-0ubuntu1)
#      gnome-shell Depends: gnome-shell-common (= 50.1-0ubuntu1.1), tecla
#      gnome-control-center Depends: mutter-common
#      ubuntu-server Depends: vim
#
# 3. Ghostty in Ubuntu 26.04 repos (verified by multiple sources):
#    https://discourse.ubuntu.com/t/ghostty-comes-to-ubuntu/80740
#    https://www.omgubuntu.co.uk/2026/04/ghostty-terminal-ubuntu-26-04-apt-install
#    https://github.com/mkasberg/ghostty-ubuntu
#
# 4. gnome-snapshot is GNOME's camera app (replaces Cheese), in GNOME Core:
#    https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app
#    https://discourse.ubuntu.com/t/cheese-discontinued-on-26-04-but-not-on-24-04-why/82002
#
# 5. xdg-user-dirs-gtk creates Desktop/Documents/Downloads/Music/Pictures/Videos
#    on first GNOME login (verified by ArchWiki, freedesktop.org, Debian):
#    https://wiki.archlinux.org/title/XDG_user_directories
#    https://www.freedesktop.org/wiki/Software/xdg-user-dirs
#    https://packages.debian.org/sid/xdg-user-dirs-gtk
#
# 6. apt autoremove protects the running kernel via
#    /etc/apt/apt.conf.d/01autoremove (kernel metapackages still need to be
#    manual to ensure future kernel upgrades install):
#    https://askubuntu.com/questions/563483/why-doesnt-apt-get-autoremove-remove-my-old-kernels
# ============================================================================
