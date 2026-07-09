# Pure GNOME 26.04 (Server → minimal vanilla GNOME)

Install a **clean, upstream GNOME 50** desktop on a fresh **Ubuntu 26.04 LTS Server**
install — no Ubuntu session, no Yaru theme, no Ubuntu extensions, no Snap, no
pre-installed bloat apps.

This is the setup used on a laptop that started life as an Ubuntu *Server* ISO
(on purpose, to avoid the desktop bloat) and was turned into a minimal,
fully-functional GNOME machine.

## What you get

- **Vanilla GNOME 50** (Wayland) — shell, session, GDM login, Settings,
  Files (Nautilus), sound (PipeWire), portals, online accounts.
- **ghostty** as the *only* terminal emulator.
- **NetworkManager** (what upstream GNOME expects) managing networking,
  including Wi-Fi.
- **gnome-snapshot** (camera app) and **htop** are kept/installed.
- **Google Chrome** installed (remove that section if you don't want it).
- The ~512 MB the kernel reserves for the crash dump is reclaimed.

## What you don't get

- No `ubuntu-session`, no `yaru-theme-*`, no `gnome-shell-ubuntu-extensions`
  (no Ubuntu dock / Ubuntu theming). At the GDM login screen the **only**
  session offered is the vanilla **GNOME** session.
- No Snap daemon, no Firefox-as-Snap.
- None of the optional GNOME apps (calculator, calendar, clocks, contacts,
  maps, weather, disks, characters, fonts viewer, logs, text editor, image
  viewer, PDF viewer, video player, scanner, system monitor, etc.).
- No `vim` (came from the server base set).

## Requirements

- A **fresh Ubuntu 26.04 LTS Server** install (or minimal) with `sudo`.
- An internet connection for package downloads.
- Works on any hardware (laptop / desktop / server) — networking is handled
  generically via NetworkManager.

## Usage

```bash
sudo bash debloat.sh
sudo reboot
```

After reboot you'll land on the GDM login screen. Log in and you get pure
GNOME. Open a terminal with **ghostty** (it's the system default terminal).

## How it stays pure (important)

1. GNOME is installed with `apt-get install --no-install-recommends gnome-core`.
   Ubuntu's `gnome-shell`/`gdm3` *Recommend* `ubuntu-session`, so skipping
   Recommends is what keeps the Ubuntu skin out.
2. After install, the optional GNOME apps and `ubuntu-session`/Yaru/Snap are
   written to `/etc/apt/preferences.d/block-gnome-bloat` with `Pin-Priority: -1`.
   This means a future `apt upgrade` can **never** reinstall them.
3. The core GNOME packages are marked `apt-mark manual` so they survive
   `apt autoremove`.

## Customizing

- **Remove Chrome:** delete the "Google Chrome" block in the script before running.
- **Keep more GNOME apps:** edit the removal list in step 4 of the script
  (e.g. remove `gnome-calculator` from the list if you want it).
- **Different terminal:** replace `ghostty` with your terminal of choice and
  update the `update-alternatives` line.

## What the script does, step by step

1. `apt-get update`
2. Install `gnome-core` (vanilla, no recommends) + mark core packages manual
3. Install & enable **NetworkManager**, set netplan `renderer: NetworkManager`
4. Install **ghostty**, remove `ptyxis` + any stray terminals, register ghostty
   as the system terminal
5. Remove optional GNOME apps + the GNOME Software store
6. Write apt pins blocking Ubuntu skin / Snap / removed apps / extra terminals
7. Drop the `gnome-core` metapackage wrapper
8. Reclaim crashkernel reserved memory (`kdump-tools` + grub snippet)
9. Install `htop` + Google Chrome
10. `apt autoremove --purge` (core is protected)
11. Enable **GDM** and set the `graphical` boot target

## Troubleshooting

- **Black screen / no GDM after reboot:** confirm `systemctl is-enabled gdm3`
  is `alias`/`enabled` and `/etc/X11/default-display-manager` is
  `/usr/sbin/gdm3`. Re-run step 11 if needed.
- **Wi-Fi not connecting:** NetworkManager manages it; check
  `nmcli device status`. Your netplan Wi-Fi config is migrated automatically.
- **A removed app came back:** it shouldn't (pins block it). Run
  `apt-cache policy <pkg>` to confirm the pin is active.

## License

MIT — do whatever you want with it.
