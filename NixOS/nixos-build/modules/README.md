# System Modules

Each file in `modules/` is a focused NixOS module that handles exactly one system concern. Modules are imported in `configuration.nix` either unconditionally or behind a feature flag.

---

## Module Reference

### audio.nix

Enables PipeWire as the system audio stack.

- Replaces PulseAudio and JACK
- Required for Hyprland and most Wayland desktops
- Enabled unconditionally

---

### bootloader.nix

Configures the GRUB bootloader.

- Sets up GRUB for EFI or BIOS systems
- Paired with `grub-theme.nix` for visual customization

---

### grub-theme.nix

Applies a custom theme to the GRUB boot menu.

---

### kernel-params.nix

Kernel parameters for generic (non-Nvidia) systems.

> **Nvidia users:** Comment this import and uncomment `kernel-params-nvidia.nix` in `configuration.nix`. Review the Nvidia module and adjust parameters for your specific GPU — do not use generic parameters blindly.

---

### kernel-params-nvidia.nix

Kernel parameters for Nvidia GPU systems.

Enables modesetting and required Nvidia-specific tweaks. Replace `kernel-params.nix` with this when the system has an Nvidia GPU.

---

### locale.nix

Sets system timezone and locale (language, character encoding).

> **Customize this:** Verify the locale matches your region before first rebuild.

---

### networking.nix

Sets the system hostname and any networking-related settings.

> **Customize this:** Change the hostname to match your machine.

---

### nix-ld.nix

Enables `nix-ld`, a compatibility shim that allows dynamically linked binaries (not packaged for NixOS) to run without patching them.

Useful when running pre-compiled binaries or development tools that assume a standard FHS layout.

---

### nixvim.nix

Configures Neovim via the NixVim module. Allows declarative Neovim configuration from within the NixOS config.

---

### quickshell.nix

Configures Quickshell, a QML-based compositor shell layer for building desktop widgets and panels.

---

### rebuild-error-hook.nix

A post-rebuild systemd hook that fires a notification when `nixos-rebuild` fails. Helps catch silent failures when rebuilding in the background.

---

### sddm.nix

Configures SDDM as the display/login manager.

- Wayland-compatible
- Works with Hyprland and KDE sessions

---

### users.nix

Defines user accounts, groups, and shell assignments.

> **Customize this:** Change the username, description, and any group memberships to match your setup.

---

### virtualbox.nix

Enables VirtualBox with kernel modules.

Feature-gated (`features.virtualisation = true`). Disabled by default because it significantly increases build time.

---

### window-managers.nix

Wires up the Hyprland session into the display manager. Enables session files, portal support, and any required system-level Hyprland settings.

Feature-gated (`features.hyprland = true`).

---

### zsh.nix

Configures Zsh as the system shell.

- Enables Zsh system-wide
- Sets up completion, history, and any plugins defined here

---

### environment.nix

Sets global environment variables exported to all sessions.

---

### uwu/nixowos.nix

Optional aesthetic module. Enables visual and meme-adjacent extras.

Feature-gated (`features.uwu = true`). Safe to disable with no functional impact.

---

## Adding a New Module

1. Create `modules/your-module.nix` following the standard NixOS module pattern.
2. Add it to the `imports` list in `configuration.nix` (unconditional or behind a `lib.optionals` feature flag).
3. Document it in this file.

---

## Code of Conduct

- One module, one responsibility.
- Prefer `lib.mkIf features.X` over unconditional imports for optional functionality.
- If a module is unclear, add a comment block inside it explaining what it does and why.
- Do not mix package installation with system configuration in the same module.
