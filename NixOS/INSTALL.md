# NixOS Installation & Setup Guide

## Quick Start

Follow these steps to set up this NixOS configuration on a fresh install.

### Prerequisites

- Fresh NixOS installation with a base system running
- Internet connectivity
- `sudo` or root access
- `git` available (comes with most NixOS installs)

---

## Step 1 — Initial System Upgrade

Bring the system up to date before making changes:

```bash
sudo nixos-rebuild switch --upgrade
```

---

## Step 2 — Clone the Repository

```bash
cd ~
git clone https://github.com/tak0dan/WtfOS.git
cd WtfOS
```

---

## Step 3 — Copy Configuration to NixOS

```bash
sudo cp -r NixOS/nixos-build/* /etc/nixos/
```

This places the modular configuration, modules, packages, and Nixorcist into `/etc/nixos/`.

> **Backup first:** If you have an existing `/etc/nixos/configuration.nix`, back it up before copying.

---

## Step 4 — Adjust Your hardware-configuration.nix

The `hardware-configuration.nix` in this repo is machine-specific. Replace it with your own:

```bash
sudo cp /etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix.bak
# Re-generate if needed:
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
```

---

## Step 5 — Customize Configuration

Edit `/etc/nixos/configuration.nix` and adjust:

1. **Feature flags** — enable/disable Hyprland, Steam, virtualisation, etc.
2. **`modules/users.nix`** — set your username and description
3. **`modules/networking.nix`** — set your hostname
4. **`modules/locale.nix`** — verify timezone and locale

---

## Step 6 — Enable Flakes

Flakes must be enabled for Nixorcist's validation and some package options.

In `/etc/nixos/configuration.nix`, verify this is present (it is by default):

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

---

## Step 7 — Bootstrap Nixorcist

Before the first rebuild, generate the Nixorcist hub file so NixOS can evaluate the config:

```bash
sudo chmod +x /etc/nixos/nixorcist/nixorcist.sh
sudo /etc/nixos/nixorcist/nixorcist.sh gen
sudo /etc/nixos/nixorcist/nixorcist.sh hub
```

---

## Step 8 — Rebuild

```bash
sudo nixos-rebuild switch
```

This applies the full configuration. Expect it to take a while on the first run.

---

## Step 9 — Verify Installation

```bash
# Check nixorcist is reachable (added as a system package)
nixorcist help

# Check your desired features are active
hyprctl version          # if hyprland = true
systemctl status sddm    # display manager
```

---

## Automated Installation

To automate the copy and bootstrap steps:

```bash
cd ~/WtfOS/NixOS
sudo bash install.sh
```

The script will:
1. Run `nixos-rebuild switch --upgrade`
2. Copy configuration to `/etc/nixos/`
3. Bootstrap Nixorcist (`gen` + `hub`)
4. Run final rebuild

To skip the system upgrade if already done:

```bash
sudo bash install.sh --skip-upgrade
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `all-packages.nix not found` | Run `sudo nixorcist gen && sudo nixorcist hub` |
| `attribute 'X' missing` during rebuild | Run `sudo nixorcist rebuild` — smart resolver will prompt |
| `nix-command is not a known feature` | Add `nix.settings.experimental-features = [ "nix-command" "flakes" ]` |
| `fzf: command not found` | Add `fzf` to `environment.systemPackages` and rebuild |
| TUI appears garbled | Ensure terminal supports UTF-8 and ANSI escape codes |
| Nixorcist cache is stale | Delete `nixorcist/cache/pkg-validation.cache` and re-run |
| Package index missing | Run `sudo nixorcist refresh-index` |

---

## Post-Installation

### Managing Packages with Nixorcist

```bash
# Open the interactive TUI
sudo nixorcist

# Or use CLI directly
sudo nixorcist install firefox git helix
sudo nixorcist delete vim
sudo nixorcist chant -python +python3
sudo nixorcist rebuild
```

### Disabling Packages Without Editing Files

```bash
nixos-comment discord        # removes from all package lists
nixos-uncomment discord      # re-enables it
nixos-smart-rebuild          # applies the change
```

### Deploying Dotfiles

From the repo root:

```bash
./Deploy-All.sh
```

---

## System Requirements

| Component | Minimum |
|-----------|---------|
| RAM | 2 GB (4 GB recommended for compilation) |
| Disk | 5 GB free for initial build |
| NixOS version | 24.05 or later |
| Bash | 4.4+ |

---

## Documentation

For detailed information about specific components:

- [nixos-build/README.md](nixos-build/README.md) — directory structure and feature flags
- [nixos-build/modules/README.md](nixos-build/modules/README.md) — system modules reference
- [nixos-build/nixorcist/README.md](nixos-build/nixorcist/README.md) — Nixorcist overview
- [nixos-build/nixorcist/INSTALL.md](nixos-build/nixorcist/INSTALL.md) — Nixorcist installation into any NixOS config
