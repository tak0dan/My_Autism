
> ⚠️ **Do not blindly copy-paste — create a backup first.**

# WtfOS — Modular NixOS Configuration

A **modular NixOS configuration** designed to stay readable and maintainable as it grows. No monolithic `configuration.nix`. No spaghetti imports.

The system is built in layers:

1. **Core system modules** — hardware, boot, services, users, networking
2. **Window manager / desktop modules** — Hyprland, KDE runtime
3. **Package groups** — logically separated sets of software
4. **Automated package management** — Nixorcist handles the install/remove lifecycle
5. **Safe rebuild utilities** — smart rebuild with interactive error resolution

---

## Repository Layout

```
WtfOS/
├── NixOS/
│   ├── nixos-build/          ← Modular NixOS config (main entry point)
│   │   ├── configuration.nix ← Root config with feature flags
│   │   ├── modules/          ← System modules (boot, audio, users, etc.)
│   │   ├── packages/         ← Package groups (core, hyprland, games, etc.)
│   │   └── nixorcist/        ← Declarative package management tool
│   └── INSTALL.md            ← Installation guide
├── Configs/                  ← Dotfiles managed by Deploy-All.sh
├── Apps-Workarounds/         ← Application fixes and desktop overrides
├── Scripts/                  ← Standalone utility scripts
├── Files/                    ← Miscellaneous files for deployment
├── Deployment/               ← Deploy-All.sh plugin engine
├── Wallpapers/               ← Wallpaper assets
└── Deploy-All.sh             ← Dotfile deployment engine
```

---

## Design Philosophy

### 1. Modularity

Each system concern lives in its own module file. This prevents a monolithic `configuration.nix` and makes it possible to understand, disable, or replace any single component without touching everything else.

Modules cover: networking, audio, bootloader, users, window managers, shell, locale, display manager, kernel parameters, and more.

### 2. Separation of System vs. Packages

```
modules/    → how the OS works (services, hardware, system config)
packages/   → what software gets installed
```

System configuration and software installation are kept separate. This makes it easy to add or remove software without touching system-level settings.

### 3. Feature Flags

The main `configuration.nix` uses a `features` block to toggle entire subsystems:

```nix
features = {
  hyprland      = true;   # Wayland compositor
  kde           = true;   # KDE runtime (not full Plasma)
  steam         = true;   # Gaming stack
  virtualisation = false; # Docker + VirtualBox
  nixorcist     = true;   # Package management tooling
  openssh       = true;   # Remote access
  uwu           = true;   # Optional aesthetic extras
};
```

Set a feature to `false` to remove it entirely from the build. No commenting required.

### 4. Package Groups Over One Giant List

Packages are split into focused files rather than one enormous list:

```
packages/core.nix
packages/development.nix
packages/games.nix
packages/communication.nix
packages/kde.nix
packages/hyprland.nix
packages/zsh.nix
packages/waybar-weather.nix
```

Some packages appear in more than one group. This is intentional — modules stay self-contained and portable without hidden cross-dependencies.

### 5. Disabled Packages Filter

Any package can be disabled globally without editing package files:

```bash
nixos-comment discord     # removes from all package lists
nixos-uncomment discord   # re-enables it
```

The filter is stored in `packages/disabled/disabled-packages.nix` and applied at build time.

---

## Hyprland Setup

The Hyprland package module is built to support the dotfiles from:

> [https://github.com/LinuxBeginnings/Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots)

This configuration does **not** use the upstream flake. The dotfiles were reworked and integrated as plain NixOS modules to avoid external flake coupling.

**Do not use the upstream auto-install script** — it detects the distro and installs via flake. Instead:

```bash
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git -b development
cd Hyprland-Dots
chmod +x copy.sh
./copy.sh
```

Or copy the config files manually into `~/.config/hypr/`.

The dotfiles are also tracked locally under `Configs/Hyprland+linux_beginnings/` and can be deployed with:

```bash
./Deploy-All.sh
```

---

## Deployment Engine

`Deploy-All.sh` is a marker-based dotfile deployment engine.

Files in `Configs/`, `Apps-Workarounds/`, and `Files/` can embed deployment markers:

```bash
#<--[~/.config/waybar|chmod=644|type=file]-->#
```

The script scans all files for these markers and delegates to typed plugins:

| Plugin type | Behavior |
|-------------|----------|
| `file` | Install with `install -m CHMOD` |
| `symlink` | Create a forced symbolic link |
| `archive` | Extract with `tar` |
| `deployable-archive` | Extract and recursively process |
| `script-dep` | Run a dependency installer script |

See [`[README]Deploy-All`]([README]Deploy-All) and [`Deployment/Plugins/README.md`](Deployment/Plugins/README.md) for full details.

---

## Documentation Index

| Document | Contents |
|----------|----------|
| [NixOS/INSTALL.md](NixOS/INSTALL.md) | Installation guide |
| [NixOS/nixos-build/README.md](NixOS/nixos-build/README.md) | nixos-build directory overview |
| [NixOS/nixos-build/modules/README.md](NixOS/nixos-build/modules/README.md) | System modules reference |
| [NixOS/nixos-build/nixorcist/README.md](NixOS/nixos-build/nixorcist/README.md) | Nixorcist overview and usage |
| [NixOS/nixos-build/nixorcist/INSTALL.md](NixOS/nixos-build/nixorcist/INSTALL.md) | Nixorcist installation |
| [NixOS/nixos-build/nixorcist/README_cli.md](NixOS/nixos-build/nixorcist/README_cli.md) | TUI engine and visual output |
| [NixOS/nixos-build/nixorcist/README_lock.md](NixOS/nixos-build/nixorcist/README_lock.md) | Transaction engine and pipeline |
| [NixOS/nixos-build/nixorcist/README_gen.md](NixOS/nixos-build/nixorcist/README_gen.md) | Module generation |
| [NixOS/nixos-build/nixorcist/README_hub.md](NixOS/nixos-build/nixorcist/README_hub.md) | Hub aggregation |
| [NixOS/nixos-build/nixorcist/README_REBUILD.md](NixOS/nixos-build/nixorcist/README_REBUILD.md) | Smart rebuild + error resolver |
| [NixOS/nixos-build/nixorcist/README_utils.md](NixOS/nixos-build/nixorcist/README_utils.md) | Validation cache and package search |
| [Deployment/Plugins/README.md](Deployment/Plugins/README.md) | Deployment plugin types |

---

## Code of Conduct

- Keep module boundaries clear. Each module should do one thing.
- Prefer disabling features over deleting them.
- Use `nixos-comment` / `nixos-uncomment` instead of manually editing package lists.
- Keep generated Nixorcist files (`generated/`) managed through Nixorcist — do not edit by hand.
- Test changes incrementally with `nixos-smart-rebuild` before committing.
- Document new modules and workarounds in their respective README files.

---

## License

MIT
