# Configs

Dotfiles and configuration files managed by the `Deploy-All.sh` deployment engine.

Files here embed deployment markers that tell `Deploy-All.sh` where to install them and how.

---

## Marker Format

Add a marker line anywhere in a file:

```bash
#<--[~/.config/waybar|chmod=644|type=file]-->#
```

| Field | Description |
|-------|-------------|
| First field | Target directory (`~` expands to `$HOME`) |
| `chmod=` | File permissions (default: `644`) |
| `type=` | Plugin type: `file`, `symlink`, `archive`, `deployable-archive`, `script-dep` |

The marker line itself is stripped from the file before deployment.

---

## Contents

### Hyprland+linux_beginnings/

Hyprland dotfiles based on the [LinuxBeginnings/Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots) project, reworked for this setup.

```
Hyprland+linux_beginnings/hypr/
├── hyprland.conf            ← Main Hyprland config
├── hyprlock.conf            ← Screen lock config
├── hypridle.conf            ← Idle daemon config
├── UserScripts/             ← User-facing scripts (weather, wallpaper, etc.)
├── scripts/                 ← Internal scripts (brightness, volume, bars, etc.)
├── Monitor_Profiles/        ← Per-monitor layout profiles
└── initial-boot.sh          ← First-boot setup script
```

**To install these dotfiles:**

Option 1 — use Deploy-All.sh (recommended for this repo):
```bash
./Deploy-All.sh
```

Option 2 — clone upstream and copy manually:
```bash
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git -b development
cd Hyprland-Dots
chmod +x copy.sh && ./copy.sh
```

> Do not use the upstream auto-install script. It detects the distro and installs via flake, which conflicts with this NixOS setup.

### [TOP & BOT] SummitSplit v3/

Waybar theme configuration. Deployed to the appropriate Waybar config location.

---

## Code of Conduct

- Do not commit sensitive data (API keys, tokens, passwords) in config files.
- Keep each config directory focused on one application or desktop component.
- When adding new dotfiles, embed a marker so Deploy-All.sh can manage deployment.
- Document any non-obvious config options in comments within the file itself.