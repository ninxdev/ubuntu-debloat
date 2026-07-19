# Ubuntu 26.04 LTS → Pure Vanilla GNOME Desktop

A single, well-tested shell script that transforms a fresh **Ubuntu 26.04 LTS "Resolute Raccoon" Server** install into a clean, vanilla **GNOME 50** desktop — no Ubuntu skin, no Snap, no Yaru theme, no pre-installed bloat apps.

For people who want a "better Ubuntu" — install the Server ISO, run this script, reboot into a pristine GNOME desktop.

---

## Why this exists

Ubuntu Desktop ships with a lot of stuff many people don't want:
- The Ubuntu session / Yaru theme / Ubuntu extensions (skin over vanilla GNOME)
- Snap and snapd
- Two dozen GNOME utility apps (Calculator, Calendar, Maps, Weather, Contacts, Clocks, …)
- The Ptyxis terminal (Ubuntu's custom terminal)
- Crash-dump kernel memory reservation (~512 MB)

This script removes all of that and gives you **pure upstream GNOME 50** — the same session you'd get on Fedora or a from-source GNOME install — while keeping the things you actually need (NetworkManager, PipeWire, xdg user folders, GDM, ghostty).

---

## Target

| | |
|---|---|
| **OS** | Ubuntu 26.04 LTS "Resolute Raccoon" — Server edition |
| **Architecture** | x86_64 (amd64) |
| **Starting point** | Fresh Server install, no desktop environment |
| **Ending point** | Vanilla GNOME 50 desktop with ghostty + NetworkManager |

> **Not supported:** Ubuntu Desktop, Ubuntu flavours (Kubuntu/Xubuntu/etc.), 24.04 LTS or older, ARM, WSL. The script may work on close variants but is **only tested against 26.04 Server amd64**.

---

## Quick start

```bash
# 1. Boot your fresh Ubuntu 26.04 Server install
# 2. Get the script
sudo git clone https://github.com/ninxdev/ubuntu-debloat.git

# 3. Run it
cd ubuntu-debloat
sudo bash debloat.sh

# 4. Reboot
sudo reboot
```

After reboot you'll see the GDM login screen. Log in — only the vanilla **"GNOME"** session is available (there is no "Ubuntu" session anymore).

---

## What gets installed

| Component | Package | Why |
|---|---|---|
| GNOME core | `gnome-core` (with `--no-install-recommends`) | Vanilla GNOME shell + session + control center |
| Display manager | `gdm3` | Boot into graphical target |
| File manager | `nautilus` | GNOME Files |
| Terminal | `ghostty` | Modern GPU-accelerated terminal, in Ubuntu 26.04 repos |
| Networking | `network-manager` | What upstream GNOME expects; replaces netplan's networkd renderer |
| Audio | `pipewire-audio` | Modern audio stack |
| Camera | `gnome-snapshot` | GNOME's modern camera app (replaces Cheese) |
| Settings | `gnome-control-center`, `gnome-settings-daemon` | Standard GNOME settings UI |
| User folders | `xdg-user-dirs-gtk` | Creates `Desktop/`, `Documents/`, `Downloads/`, `Music/`, `Pictures/`, `Videos/` on first login |
| Extras | `htop`, `wget`, Google Chrome | Useful utilities + a real browser |

---

## What gets removed

**GNOME utility apps** (none are hard dependencies of `gnome-shell` or `gdm3` — verified):

```
gnome-calculator   gnome-calendar       gnome-characters     gnome-clocks
gnome-contacts     gnome-disk-utility   gnome-font-viewer    gnome-logs
gnome-maps         gnome-weather        gnome-sushi          gnome-system-monitor
gnome-text-editor  baobab               loupe                papers
showtime           simple-scan          gnome-connections    gnome-user-docs
yelp               orca                 gnome-software
```

**Other bloat:**
- `ptyxis` (Ubuntu's custom terminal — replaced by ghostty)
- `snapd` (and snap support)
- `gnome-core` metapackage (the wrapper, after marking what we want as manual)
- `kdump-tools` + `kexec-tools` (frees ~512 MB of reserved kernel memory)

**Apt pins** are written to `/etc/apt/preferences.d/block-gnome-bloat` so `apt upgrade` can **never** reinstall any of the above.

---

## What is KEPT (and why)

These three packages are **hard dependencies** of `gnome-shell` and CANNOT be removed or pinned without breaking GNOME. This was the bug that broke the previous version of this script.

| Package | Required by | Why it must stay |
|---|---|---|
| `tecla` | `gnome-shell`, `gnome-control-center` | Keyboard layout viewer; hard dep since GNOME 46 |
| `ubuntu-wallpapers` | `gnome-shell` | Ubuntu's patched `gnome-shell` depends on it |
| `ubuntu-wallpapers-resolute` | `ubuntu-wallpapers` | The 26.04 wallpaper pack (~63 MB) |

Removing or pinning any of these cascades through `gnome-shell → gdm3 → gnome-session` and breaks the desktop. This is **Ubuntu Bug 1894347**, open since 2020 and still present in 26.04:
<https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html>

The script marks these three as manually installed so `autoremove` will never touch them.

---

## How the script is ordered (and why)

```
1. apt update
2. Install gnome-core (no recommends) + NetworkManager + ghostty
3. apt-mark manual EVERYTHING that must survive autoremove
4. Enable gdm3 + set graphical.target          ← done EARLY, while gdm3 exists
5. Install extras (htop, Chrome)
6. Remove kdump-tools (free 512 MB)
7. Remove gnome-core metapackage
8. Remove optional GNOME apps                   ← app removal
9. Remove ptyxis + snapd
10. Write apt pins (Priority -1)                ← pinning
11. apt autoremove --purge                      ← LAST
12. Sanity check: gdm3.service exists?
```

**Why GDM is enabled BEFORE the apt pin:** if anything goes wrong during pinning or autoremove, `gdm3.service` is already registered and the system can still boot to a graphical target. The previous version of this script enabled GDM at the very end — by which point `autoremove` had already purged `gdm3` (because the pin broke its dependency chain), producing:

```
Failed to enable unit: Unit gdm3.service does not exist
```

**Why app removal and pinning are LAST:** so that if you Ctrl-C the script mid-way, you still have a working system with GNOME installed. The destructive operations happen at the end after everything important is already protected by `apt-mark manual`.

---

## Prerequisites

1. **A fresh Ubuntu 26.04 LTS Server install.** Don't run this on Ubuntu Desktop — it's designed for Server → Desktop conversion.
2. **Internet access** (the script installs packages and adds the Google Chrome repo).
3. **`sudo` privileges.**
4. **At least 5 GB free disk space** (GNOME + Chrome + deps).

---

## Verification

This script was verified by:

1. **Fetching the actual Ubuntu 26.04 resolute `Packages.gz` metadata** (main, universe, restricted, multiverse, updates, security — 8 sources) from `archive.ubuntu.com`.
2. **Building a pure-Python apt dependency resolver** that traces every install/remove/autoremove decision using that real metadata.
3. **Reverse-dependency analysis** of every package in the remove/pin list to confirm none are hard deps of `gnome-shell`, `gdm3`, `gnome-control-center`, `gnome-session`, `nautilus`, or `ubuntu-server`.
4. **End-to-end simulation** of the script confirming:
   - `gdm3.service` exists at the end
   - All GNOME core packages survive `autoremove`
   - Kernel metapackages are not purged
   - All 23 optional GNOME apps are removed
   - Recovery `apt install gdm3` would succeed even after the pin is in place
5. **Real-world testing in VMware** on Ubuntu 26.04 LTS Server amd64.

---

## Troubleshooting

### `Failed to enable unit: Unit gdm3.service does not exist`

This means `gdm3` was removed somewhere along the way. The current version of the script should not produce this — but if it does, run:

```bash
sudo apt-mark unhold $(apt-mark showhold)  # clear any holds
sudo apt install gdm3 gnome-shell gnome-session
sudo systemctl enable gdm3
sudo systemctl set-default graphical.target
```

If `apt install gdm3` fails with "ubuntu-wallpapers-resolute is not installable", check `/etc/apt/preferences.d/block-gnome-bloat` — `ubuntu-wallpapers-resolute` must NOT be in the `Package:` line. Remove it if present, then `sudo apt update && sudo apt install gdm3`.

### Black screen after reboot

Wait 30 seconds, then Ctrl+Alt+F2 to switch to a TTY. Log in and run:

```bash
sudo systemctl status gdm3
sudo journalctl -u gdm3 -b
```

If GDM is failing because of a graphics driver issue, install the appropriate driver:

```bash
# For VMware:
sudo apt install open-vm-tools open-vm-tools-desktop
# For VirtualBox:
sudo apt install virtualbox-guest-utils virtualbox-guest-x11
# For real hardware with NVIDIA:
sudo ubuntu-drivers autoinstall
```

### No network after reboot

NetworkManager should manage networking automatically. If not:

```bash
nmcli device status
sudo nmtui  # text UI to configure connections
```

### `apt update` warnings about pinned packages

This is normal and harmless — `apt` is just informing you that some packages are blocked by the pin. That's the intended behavior.

### I want to undo a pin

Edit `/etc/apt/preferences.d/block-gnome-bloat` and remove the package name from the `Package:` line, then `sudo apt update`.

### I want to undo everything

```bash
sudo rm /etc/apt/preferences.d/block-gnome-bloat
sudo apt update
sudo apt install ubuntu-desktop
```

This will reinstall the full Ubuntu Desktop with all the bloat. You may need to fix `apt-mark` flags first:

```bash
sudo apt-mark auto $(apt-mark showmanual | grep -E 'gnome-|tecla|ubuntu-wallpapers')
```

---

## FAQ

**Q: Why Ubuntu Server as the base, not Ubuntu Desktop?**
A: Ubuntu Desktop ships with Snap, the Ubuntu session, Yaru, and ~1 GB of extra packages. Starting from Server gives you a clean slate. This script then installs only the GNOME packages you actually want.

**Q: Will this work on Ubuntu 26.10, 27.04, etc.?**
A: Not as-is. Package names and dependency chains change between releases. You'll need to re-verify the dependency chains (the script's evidence section explains how) and update the `apt-mark manual` and pin lists accordingly.

**Q: Why ghostty and not ptyxis / gnome-terminal / alacritty?**
A: ghostty is in the official Ubuntu 26.04 repos ([announcement](https://discourse.ubuntu.com/t/ghostty-comes-to-ubuntu/80740)), is GPU-accelerated, and is the user's preference. The script removes ptyxis (Ubuntu's default) and pins it so it can't come back. To use a different terminal, edit section 3 of the script.

**Q: Why is `gnome-snapshot` kept? Isn't it just a camera app?**
A: It's part of GNOME Core and is the modern replacement for Cheese (Ubuntu 24.04+ switched to it: [OMG Ubuntu article](https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app)). It's tiny and doesn't hurt to keep.

**Q: Can I remove `vim`? The script doesn't.**
A: `ubuntu-server` (which is still installed) hard-depends on `vim`. If you want to remove `vim`, first remove the `ubuntu-server` metapackage:
```bash
sudo apt remove ubuntu-server
sudo apt autoremove --purge
```
This is a separate decision and not part of this script.

**Q: The script installed Google Chrome. I don't want it.**
A: Comment out section 6 of the script (the Chrome `wget` + `apt-get install` block).

**Q: How much disk space does this save vs. Ubuntu Desktop?**
A: Roughly 1.5–2 GB removed (Snap runtime + Ubuntu session + 23 GNOME apps + wallpapers-except-resolute + Ptyxis). The script also frees ~512 MB of kernel-reserved crash-dump memory.

**Q: Is this safe to run on a production server?**
A: **No.** This converts a server into a desktop. If you have a production server, don't run this. If you want a desktop, install Ubuntu Desktop or use this script on a fresh Server install.

---

## Contributing

Found a bug? Want to verify for a new Ubuntu release?

1. **Reproduce the verification yourself.** The script's evidence section links to the `Packages.gz` files used. Download them and trace the dependency chains.
2. **Open an issue** with:
   - The exact Ubuntu release and architecture
   - The full output of the script (or the failing step)
   - The output of `apt-cache depends --recurse gdm3 gnome-shell` on your system
3. **Pull requests welcome** — but only with verified changes. Don't add or remove packages without checking the reverse-dependencies first.

### How to verify a package is safe to pin

```bash
# What hard-depends on the package?
apt-cache rdepends --installed <package>

# Is it a hard dep of any critical package?
apt-cache rdepends --installed <package> | grep -E 'gnome-shell|gdm3|gnome-session|gnome-control-center|ubuntu-server'

# If the second command returns anything, DO NOT pin or remove the package.
```

---

## References

- **Ubuntu Bug 1894347** — "Can't uninstall ubuntu-wallpapers and ubuntu-wallpapers-bionic without gnome-shell": <https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html>
- **Ghostty in Ubuntu 26.04** — official announcement: <https://discourse.ubuntu.com/t/ghostty-comes-to-ubuntu/80740>
- **gnome-snapshot replaces Cheese** — <https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app>
- **xdg-user-dirs** (creates Desktop/Documents/Downloads/etc.) — <https://wiki.archlinux.org/title/XDG_user_directories>
- **Ubuntu 26.04 Packages.gz** (the metadata used for verification) — <http://archive.ubuntu.com/ubuntu/dists/resolute/main/binary-amd64/Packages.gz>

---

## License

GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for the full text.

---

## Disclaimer

This script modifies your system's package state, removes packages, writes apt pins, and changes boot targets. **Test it in a VM first.** Take a snapshot before running on real hardware. The author is not responsible for broken systems, lost data, or bricked installs.
