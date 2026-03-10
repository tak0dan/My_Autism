[⚠️⚠️⚠️] DO NOT COPY AND PASTE IT BLINDLY, CREATE BACKUP FIRST[⚠️⚠️⚠️] 

# Got a backup already? Good :) 

# Allow me to introduce:




# WtfOS — Modular NixOS Configuration

This repository contains a **modular NixOS configuration** designed to be readable, maintainable, and easy to expand without turning `configuration.nix` into a giant unreadable mess.

The system follows a **layered architecture**:

1. **Core system modules** — hardware, services, users, networking  
2. **Window manager / desktop modules** — Hyprland, KDE, etc.  
3. **Package groups** — logically separated sets of software  
4. **Automated package management (Nixorcist)**  
5. **Safe rebuild utilities**

The result is a configuration that can scale without becoming chaotic.

---

# Documentation Index

Main and module documentation entry points:

- [NixOS/nixos-build/modules/README.md](NixOS/nixos-build/modules/README.md) - Core system modules overview
- [NixOS/nixos-build/nixorcist/README.md](NixOS/nixos-build/nixorcist/README.md) - Nixorcist main documentation

Nixorcist technical documentation:

- [NixOS/nixos-build/nixorcist/README_cli.md](NixOS/nixos-build/nixorcist/README_cli.md) - CLI interface
- [NixOS/nixos-build/nixorcist/README_lock.md](NixOS/nixos-build/nixorcist/README_lock.md) - Lock and transaction engine
- [NixOS/nixos-build/nixorcist/README_utils.md](NixOS/nixos-build/nixorcist/README_utils.md) - Utility and validation layer
- [NixOS/nixos-build/nixorcist/README_gen.md](NixOS/nixos-build/nixorcist/README_gen.md) - Module generation pipeline
- [NixOS/nixos-build/nixorcist/README_hub.md](NixOS/nixos-build/nixorcist/README_hub.md) - Hub regeneration flow
- [NixOS/nixos-build/nixorcist/README_rebuild.md](NixOS/nixos-build/nixorcist/README_rebuild.md) - Rebuild and staging flow

Reference-format variants:

- [NixOS/nixos-build/nixorcist/README_CLI.md](NixOS/nixos-build/nixorcist/README_CLI.md)
- [NixOS/nixos-build/nixorcist/README_LOCK.md](NixOS/nixos-build/nixorcist/README_LOCK.md)
- [NixOS/nixos-build/nixorcist/README_UTILS.md](NixOS/nixos-build/nixorcist/README_UTILS.md)
- [NixOS/nixos-build/nixorcist/README_GEN.md](NixOS/nixos-build/nixorcist/README_GEN.md)
- [NixOS/nixos-build/nixorcist/README_HUB.md](NixOS/nixos-build/nixorcist/README_HUB.md)
- [NixOS/nixos-build/nixorcist/README_REBUILD.md](NixOS/nixos-build/nixorcist/README_REBUILD.md)

---

# Design Philosophy

The configuration follows several principles.

## 1. Modularity

Each system component lives in its own module:

- networking
- audio
- bootloader
- users
- window managers
- shell configuration

This prevents a monolithic `configuration.nix`.

---

## 2. Separation of System vs Packages

The repository separates system configuration from software installation.

modules/   → system configuration packages/  → software groups

System configuration defines **how the OS works**.

Package modules define **what software gets installed**.

---

## 3. Package Groups Instead of One Giant List

Instead of writing something like:

environment.systemPackages = with pkgs; [ git firefox neovim ripgrep ];

Packages are split into modules such as:

packages/core.nix packages/development.nix packages/games.nix packages/communication.nix packages/kde.nix packages/hyprland.nix

This keeps each category logically grouped.

---

# Package Modules

Each file inside `/packages` is intended to be **independent**.

Because of this design, **some packages may appear in multiple modules**.

This is intentional.

Reasons:

- modules can be enabled independently  
- modules remain portable  
- dependencies stay local to the module

This avoids hidden dependencies between modules.

Example scenario:

hyprland module needs:

wl-clipboard grim slurp

These packages might also appear in:

core module development module

This duplication is **deliberate and harmless**.

---

# Hyprland Module

The Hyprland module is designed specifically to support the configuration from:

[https://github.com/LinuxBeginnings/Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots)

However, this configuration **does not rely on the flake** provided by that project.
Instead:

- the configuration was reworked
- converted into modular NixOS modules
- integrated into this repository structure

This avoids tight coupling to an external flake.

So for the better experience I suggest to install it next way:

It is not suggested to use the auto-installation script since it detects the distro and installs the dotfiles with flake.
Instead do: 
```
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git -b development
cd Hyprland-Dots
```
Copy them manually or use the copying script:
```
chmod +x copy.sh
./copy.sh
```
---

# Achieving the "Zen Hyprland" Setup

To replicate the intended Hyprland experience:

## 1. Clone the original dotfiles
```
git clone https://github.com/LinuxBeginnings/Hyprland-Dots
```

## 2. Replace certain configs

Override parts of the cloned configuration using the files from:
[https://github.com/tak0dan/WtfOS/tree/main/Configs/Hyprland%2Blinux_beginnings](https://github.com/tak0dan/WtfOS/tree/main/Configs/Hyprland%2Blinux_beginnings)

Specifically:

waybar btop wallust

Example:
```
cp -r /path/to/cloned/configs/* ~/.config/
```
These overrides adapt the original dotfiles to work perfectly with this NixOS configuration.

Without these overrides some visual elements or scripts may behave differently.

---

# Kernel Parameters

Kernel parameters are located in:

modules/kernel-params.nix

If the system uses **NVIDIA GPUs**, replace it with:

modules/kernel-params-nvidia.nix

However, the best approach is to generate parameters based on your own hardware.

You can:

- copy parameters from a clean `configuration.nix`
- adjust them for your system

Kernel parameters should always match the specific hardware environment.

---

# Nixorcist Package Management

This repository includes **Nixorcist**, a helper tool for managing packages.

It introduces a workflow where packages are defined through:

lock file ↓ generated modules ↓ hub module ↓ system rebuild

Instead of editing package lists manually.

Basic usage(It might need sudo) :

```
nixorcist select
```

Then:
```
nixorcist gen 
nixorcist hub 
nixorcist rebuild
```
Or run everything:
```
nixorcist all
```
This system generates Nix modules automatically from the lock file.

---

# Smart Rebuild Script

The repository includes a rebuild helper:

scripts/nix-rebuild-smart.sh

The script improves the normal rebuild process by:

- detecting evaluation warnings
- locating renamed options
- offering automated replacements
- interactive confirmation mode

This helps maintain the system when NixOS changes option names between releases.

---

# Typical Workflow

## Add packages

nixorcist select

## Generate modules

nixorcist gen

## Update hub

nixorcist hub

## Rebuild system

nixorcist rebuild

Or simply:
```
nixorcist all
```
---

# Goals of this Configuration

The system is designed to achieve:

- **clarity** — everything lives in the correct module  
- **scalability** — easy to add new components  
- **reproducibility** — reliable rebuilds  
- **experimentation** — safe environment for testing  
- **automation** — less manual editing

---

# Notes

Some modules or directories may evolve over time as the configuration continues to be refined.

The structure is intentionally flexible so that:

- new package groups  
- new desktop environments  
- additional automation tools  

can be integrated without restructuring the entire system.

---

# License

MIT
