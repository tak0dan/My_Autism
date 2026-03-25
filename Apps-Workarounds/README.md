# Application Workarounds

Custom fixes for application behavior on this system. Each workaround is isolated and addresses a specific breakage or compatibility issue.

---

## Contents

### eclipse-x11.desktop

Desktop entry override for Eclipse IDE. Forces Eclipse to run under XWayland (X11 mode) instead of native Wayland, which resolves rendering and input issues under Hyprland.

Deploy with:
```bash
./Deploy-All.sh
```

Or manually copy to `~/.local/share/applications/`.

---

### dia-x11.desktop

Desktop entry override for the Dia diagram editor. Forces X11 rendering to avoid Wayland-related display issues (missing menus, broken DnD) under Hyprland.

---

### dia-deps.sh

Dependency installer for Dia. Detects the package manager and installs Dia with the correct GTK2 engine for the current distribution.

**Supported:** pacman/paru/yay, apt, dnf, zypper, xbps-install, emerge, nix-env

```bash
bash dia-deps.sh
```

The script also carries a `script-dep` deployment marker so `Deploy-All.sh` can trigger it automatically when deploying `dia-x11.desktop`.

---

## When to Add a Workaround

Add a workaround here when:

- Default application behavior is broken under Wayland/Hyprland
- An X11 fallback is needed for a specific app
- A system-specific desktop entry override is required
- A one-off dependency installer is needed for an app not in the NixOS config

---

## Code of Conduct

- Keep workarounds isolated — one file per application, one problem per file.
- Document what the workaround fixes and why it is needed.
- Prefer fixing things in the NixOS config (modules, packages) over workarounds where possible.
- If a workaround becomes permanent, consider upstreaming it or adding it to the NixOS module.
