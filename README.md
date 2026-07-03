# Ubuntu 26.04 LTS Debloat Script

A comprehensive debloat script for Ubuntu 26.04 LTS (GNOME 50).

## Features

- Removes Snap completely
- Removes Flatpak completely
- Removes Ubuntu-specific packages and services
- Removes unnecessary GNOME applications
- Installs GNOME Extension Manager
- Pins removed packages to prevent automatic reinstallation
- Supports dry-run mode
- Includes rollback support
- Detailed logging
- No user-specific software installation

## Requirements

- Ubuntu 26.04 LTS
- GNOME 50+
- Root privileges

## Usage

```bash
chmod +x ubuntu-2604-debloat.sh
sudo ./ubuntu-2604-debloat.sh
