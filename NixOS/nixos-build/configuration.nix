{ config, pkgs, lib, ... }:

# =============================================================================
#                           🧠 CONFIG OVERVIEW
# =============================================================================
# Modular NixOS configuration driven by feature flags and GPU profiles.
#
# ┌─ HOW TO USE ───────────────────────────────────────────────────────────┐
# │  1. Set your options in the `features` block below.                    │
# │  2. Run: nixos-smart-rebuild                                           │
# │  3. If something breaks, check which feature flag controls it.         │
# └────────────────────────────────────────────────────────────────────────┘
#
# ┌─ MODULE LOADING RULES ─────────────────────────────────────────────────┐
# │  Always loaded:                                                        │
# │    hardware, boot, display/login, core system, shell, gpu.nix          │
# │                                                                        │
# │  Loaded when features.hyprland = true:                                 │
# │    window-managers, portals, quickshell, fonts, theme, overlays, nh    │
# │    vm-guest-services (*), local-hardware-clock (*)                     │
# │    (*) imported but inactive until their own option is set             │
# │                                                                        │
# │  GPU kernel params: always applied when gpu != "none"                  │
# │  GPU kernel params + drivers: always applied when gpu != "none"        │
# └────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================


# =============================================================================
#                           🚀 FEATURE TOGGLES
# =============================================================================
let
  features = {

    # =========================================================================
    # 🪟 HYPRLAND
    # =========================================================================
    # Wayland compositor (tiling window manager).
    #
    # Turning this ON also loads:
    #   modules/window-managers.nix   — Hyprland + bspwm/i3 fallback
    #   modules/portals.nix           — XDG desktop portals (screen share, etc.)
    #   modules/quickshell.nix        — Wayland shell widget system
    #   modules/fonts.nix             — Large font collection for bars/terminals
    #   modules/theme.nix             — GTK/cursor/dconf dark theme
    #   modules/overlays.nix          — nixpkgs patches (waybar-weather, etc.)
    #   modules/nh.nix                — Nix helper + nix-output-monitor
    #   modules/vm-guest-services.nix — (inactive unless vm.guest-services.enable)
    #   modules/local-hardware-clock.nix — (inactive unless local.hardware-clock.enable)
    #   packages/hyprland.nix         — Hyprland-specific user packages
    #
    hyprland = true;

    # =========================================================================
    # 🖥️  HARDWARE PROFILES
    # =========================================================================
    #==========================================================================
    #==========================================================================
    # 🖥️  KERNEL PARAMS PROFILE  (mandatory — "generic" is safe for any hardware)
    # =========================================================================
    # Selects boot-time kernel tuning. No dependency on any software feature.
    # Owns: boot.kernelParams, boot.kernelModules, boot.initrd.*, hardware.cpu.*,
    #       hardware.enableRedistributableFirmware, power management services.
    #
    # "generic"   Sane defaults for any hardware
    #               → sysrq, panic auto-reboot, swappiness, firmware
    # "thinkpad"  ThinkPad T480
    #               → i915 GuC/HuC firmware, framebuffer compression,
    #                 Intel microcode, power-profiles-daemon, sysctl tuning
    # "nvidia"    Generic discrete Nvidia
    #               → nvidia modules in initrd, DRM modesetting,
    #                 cold-boot PCI rebind fix
    #             Pair with:  driver = "nvidia"  or  driver = "nvidia-prime"
    # "amd"       AMD system
    #               → amd_iommu, ppfeaturemask, AMD microcode, early amdgpu load
    #             Pair with:  driver = "amd"
    #
    kernelParams = "thinkpad";

    # =========================================================================
    # 🎮 GPU DRIVER PROFILE  (optional — "none" loads no driver module)
    # =========================================================================
    # Selects the GPU driver. No dependency on any software feature.
    # Owns: services.xserver.videoDrivers, hardware.nvidia.*, hardware.graphics
    #       extraPackages (VA-API, VDPAU libs).
    # Does NOT touch boot.* — that is kernelParams' responsibility.
    #
    # "none"         No GPU driver (VM, headless, or built-in Intel without extras)
    # "amd"          AMD — amdgpu videoDriver + VA-API packages
    #                Pair with:  kernelParams = "amd"
    # "intel"        Intel integrated — intel-media-driver + VA-API
    #                Pair with:  kernelParams = "generic"  or  "thinkpad"
    # "nvidia"       Nvidia discrete — full hardware.nvidia config
    #                Pair with:  kernelParams = "nvidia"
    # "nvidia-prime" Nvidia + Intel PRIME hybrid offload
    #                Pair with:  kernelParams = "nvidia"
    #
    gpu = "none";

    # =========================================================================
    # 🎨 KDE RUNTIME
    # =========================================================================
    # KDE libraries and Qt integration for apps — does NOT install Plasma.
    #
    # Enables:
    #   - Qt platform theme (kde)
    #   - polkit-kde-agent-1 (authentication popups, wired to hyprland-session)
    #   - KIO admin integration
    #   - QML import paths for Qt5 declarative apps
    #   - packages/kde.nix user packages
    #
    # ⚠️  polkit-kde-agent is hardwired to hyprland-session.target.
    #     If hyprland = false, polkit popups will not auto-start.
    #
    kde = true;

    # =========================================================================
    # 🎮 STEAM / GAMING
    # =========================================================================
    # Enables:
    #   - Steam with Gamescope session
    #   - GameMode (performance governor on game launch)
    #   - packages/games.nix user packages
    #
    steam = true;

    # =========================================================================
    # 🐾 UWU  (meme / aesthetic stack)
    # =========================================================================
    # Enables modules/uwu/nixowos.nix (denix-based home-manager wrapper).
    #
    # ⚠️  When uwu = true, home-manager is provided by nixowos → denix.
    #     The standalone <home-manager/nixos> channel module is NOT imported
    #     to avoid duplicate option declaration errors.
    #     Setting both uwu = true AND home-manager = true is safe — the
    #     import guard below handles deduplication automatically.
    #
    uwu = true;

    # =========================================================================
    # 📦 VIRTUALISATION
    # =========================================================================
    # Enables Docker + imports modules/virtualbox.nix.
    #
    # ⚠️  VirtualBox kernel module takes significant time to build.
    #     Disable on first rebuild if you don't need it immediately.
    #
    virtualisation = true;

    # =========================================================================
    # 🤖 NIXORCIST
    # =========================================================================
    # Custom package automation system (see /etc/nixos/nixorcist/).
    # Exposes the `nixorcist` CLI and loads auto-generated package lists.
    #
    nixorcist = true;

    # =========================================================================
    # 🔐 OPENSSH
    # =========================================================================
    # Enables the SSH daemon for remote access.
    #
    # ⚠️  Password authentication is ON. Switch to key-based auth for
    #     production or internet-exposed machines.
    #
    openssh = true;

    # =========================================================================
    # 🏠 HOME-MANAGER
    # =========================================================================
    # Declarative management of /home/ (dotfiles, user packages, services).
    # Reads configuration from ~/.hm-local/home.nix (or default.nix).
    # Falls back gracefully if the file does not exist.
    #
    # ⚠️  When uwu = true this flag is still respected for user config
    #     loading, but the NixOS module itself comes from nixowos/denix.
    #
    home-manager = true;

    # =========================================================================
    # 🤖 GITHUB COPILOT CLI
    # =========================================================================
    # Installs the GitHub Copilot CLI via the official installer script.
    # Runs: curl -fsSL https://gh.io/copilot-install | bash
    #
    # ⚠️  Requires internet access on first activation.
    #     Installation is guarded by a sentinel file and only runs once.
    #     To re-install, remove: /var/lib/copilot-cli/.installed
    #
    copilot = true;
  };


  # ===========================================================================
  # 🚫 DISABLED PACKAGES
  # ===========================================================================
  # Packages listed here are filtered out from ALL package groups globally.
  # Managed by the CLI tools below — prefer those over manual edits.
  #
  #   nixos-comment   <pkg>   disable a package
  #   nixos-uncomment <pkg>   re-enable a package
  #
  # Source of truth: /etc/nixos/packages/disabled/disabled-packages.nix
  # Format: [ "steam" "discord" "telegram-desktop" ]
  #
  disabledPackages =
    import ./packages/disabled/disabled-packages.nix;

  isEnabled = pkg:
    !(builtins.elem (lib.getName pkg) disabledPackages);

  filterPkgs = list:
    builtins.filter isEnabled list;


in
{

  # ===========================================================================
  # 📦 IMPORTS
  # ===========================================================================
  # Modules are split into three groups:
  #
  #   1. Always loaded — hardware, boot, core system, gpu.nix
  #   2. Conditionally loaded — driven by feature flags above
  #   3. Never import the individual driver modules directly;
  #      gpu.nix manages amd/intel/nvidia/nvidia-prime internally.
  #
  imports =
   [
     # --- Hardware ---
     ./hardware-configuration.nix

     # --- Boot ---
     ./modules/bootloader.nix
     ./modules/grub-theme.nix

     # --- GPU (always loaded; profile + driver activation via features above) ---
     # gpu.nix pulls in: kernel-params.nix, kernel-params-nvidia.nix,
     #                   amd-drivers.nix, intel-drivers.nix,
     #                   nvidia-drivers.nix, nvidia-prime-drivers.nix
     # Activation is controlled by gpu.kernelParams and gpu.driver below.
     ./modules/gpu.nix

     # --- Display / Login ---
     ./modules/sddm.nix

     # --- Core system ---
     ./modules/locale.nix
     ./modules/networking.nix
     ./modules/users.nix
     ./modules/audio.nix

     # --- Shell / environment ---
     ./modules/environment.nix
     ./modules/zsh.nix
     ./modules/rebuild-error-hook.nix

     # --- Compatibility ---
     ./modules/nix-ld.nix

     # --- Auto-generated package lists (managed by nixorcist) ---
     ./nixorcist/generated/all-packages.nix
   ]

   # home-manager channel module.
   # Skipped when uwu = true because nixowos/denix already provides it.
   ++ lib.optionals (features.home-manager && !features.uwu) [
     <home-manager/nixos>
   ]

   # Hyprland stack — everything that only makes sense on a Wayland compositor.
   #
   # vm-guest-services and local-hardware-clock are included here because they
   # originate from the Hyprland config set. They are safe no-ops by default;
   # activate them by setting:
   #   vm.guest-services.enable      = true;
   #   local.hardware-clock.enable   = true;
   ++ lib.optionals features.hyprland [
     # Compositor + Wayland plumbing
     ./modules/window-managers.nix   # Hyprland, bspwm, i3, xkb layout
     ./modules/portals.nix           # XDG portals: screen share, file picker
     ./modules/quickshell.nix        # Wayland shell widget layer

     # Visual environment
     ./modules/fonts.nix             # Nerd fonts, CJK, icon fonts, etc.
     ./modules/theme.nix             # GTK Adwaita-dark, cursors, dconf defaults
     ./modules/overlays.nix          # nixpkgs patches (waybar-weather, cmake fixes)

     # Tooling
     ./modules/nh.nix                # `nh` Nix helper + nix-output-monitor + nvd

     # Optional hardware support (inactive until their enable option is set)
     ./modules/vm-guest-services.nix    # QEMU guest agent + SPICE
     ./modules/local-hardware-clock.nix # RTC in local time (dual-boot Windows)
   ]

   ++ lib.optionals features.uwu [
     ./modules/uwu/nixowos.nix
   ]

   ++ lib.optionals features.virtualisation [
     ./modules/virtualbox.nix
   ];


  # ===========================================================================
  # 🏠 HOME-MANAGER USER CONFIG
  # ===========================================================================
  # Reads from ~/.hm-local/home.nix (or default.nix).
  # Falls back to a minimal config (just git) so the system never breaks
  # if the file is missing.
  #
  home-manager.users.tak_1 =
  let
    local = /home/tak_1/.hm-local;
    source = if builtins.pathExists local then local else null;
    hmFile =
      if source != null && builtins.pathExists (source + "/home.nix") then
        source + "/home.nix"
      else if source != null && builtins.pathExists (source + "/default.nix") then
        source + "/default.nix"
      else
        null;
  in
  {
    home.username = "tak_1";
    home.homeDirectory = "/home/tak_1";
    home.stateVersion = "25.11";
    home.enableNixpkgsReleaseCheck = false;
    imports = lib.optionals (hmFile != null) [ hmFile ];
    home.packages = [ pkgs.git ]; # fallback so system never fails
  };


  # ===========================================================================
  # 🔤 FONTS (base set — always loaded)
  # ===========================================================================
  # This is the minimal always-present font set.
  # The full Hyprland font collection lives in modules/fonts.nix
  # and is only loaded when features.hyprland = true.
  #
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # Main programming font
      nerd-fonts.symbols-only     # Extra glyphs/icons
    ];
  };


  # ===========================================================================
  # 🖥️  HARDWARE GRAPHICS (base)
  # ===========================================================================
  # Enables Mesa / VA-API acceleration and 32-bit libs (required for Steam).
  # GPU-specific driver config lives in modules/gpu.nix and its sub-modules.
  #
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;


  # ===========================================================================
  # 🔊 AUDIO
  # ===========================================================================
  # PipeWire as the unified audio/video server (replaces PulseAudio + JACK).
  # Full PipeWire config (ALSA/PulseAudio compat) is in modules/audio.nix.
  #
  services.pipewire.enable = true;

 
  #===========================================================================
  # KEYRINGS
  #===========================================================================
  services.gnome.gnome-keyring.enable = true;
  

  # ===========================================================================
  # 🪟 WINDOW MANAGER
  # ===========================================================================
  programs.hyprland.enable = features.hyprland;

  # Wire hardware profiles — both are purely hardware config, no software deps.
  # See the features block above for the full list of values and what each loads.
  gpu.kernelParams = features.kernelParams;
  gpu.driver       = features.gpu;


  # ===========================================================================
  # 🎨 KDE RUNTIME (libraries only — no Plasma session)
  # ===========================================================================
  # Provides Qt/KDE integration so KDE apps work well under Hyprland.
  #
  # Dependencies:
  #   - polkit-kde-agent wires itself to hyprland-session.target.
  #     If hyprland = false, authentication popups will not auto-start.
  #   - QML import paths are needed by Qt5 declarative components.
  #
  qt = lib.mkIf features.kde {
    enable = true;
    platformTheme = "kde";
  };

  environment.sessionVariables = lib.mkIf features.kde {
    QML2_IMPORT_PATH = lib.mkForce (
      lib.concatStringsSep ":" [
        "${pkgs.libsForQt5.qtgraphicaleffects}/lib/qt-5/qml"
        "${pkgs.libsForQt5.kcmutils}/lib/qt-5/qml"
        "${pkgs.libsForQt5.knewstuff}/lib/qt-5/qml"
      ]
    );
  };

  systemd.user.services.polkit-kde-agent = lib.mkIf features.kde {
    description = "Polkit KDE Authentication Agent";
    after    = [ "hyprland-session.target" ];
    wantedBy = [ "hyprland-session.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  environment.etc."xdg/menus/applications.menu".source =
    lib.mkIf features.kde
      "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";


  # ===========================================================================
  # 🌐 SSH
  # ===========================================================================
  # ⚠️  Password auth is enabled — fine for LAN, risky on the internet.
  #     Switch to key-based auth for exposed machines.
  #
  services.openssh = lib.mkIf features.openssh {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };


  # ===========================================================================
  # 📦 VIRTUALISATION
  # ===========================================================================
  virtualisation.docker.enable = features.virtualisation;


  # ===========================================================================
  # 🎮 GAMING
  # ===========================================================================
  programs.steam = lib.mkIf features.steam {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = features.steam;


  # ===========================================================================
  # ⚙️  NIX SETTINGS
  # ===========================================================================
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 324217728;
    http-connections = 50;
  };


  # ===========================================================================
  # 📦 SYSTEM PACKAGES
  # ===========================================================================
  # Assembled from multiple package files based on active features.
  # Use `nixos-comment <pkg>` to disable individual packages without editing files.
  #
  environment.systemPackages =

    # Global packages (always installed regardless of features)
    filterPkgs (import ./packages/all-packages.nix { inherit pkgs; })

    # Feature-gated package groups
    ++ lib.optionals features.kde
      (filterPkgs (import ./packages/kde.nix { inherit pkgs; }))

    ++ lib.optionals features.hyprland
      (filterPkgs (import ./packages/hyprland.nix { inherit pkgs; }))

    ++ lib.optionals features.steam
      (filterPkgs (import ./packages/games.nix { inherit pkgs; }))

    # Always-installed system utilities
    ++ [
      pkgs.kdePackages.polkit-kde-agent-1
      pkgs.kdePackages.kio-admin
      pkgs.hyprland-qt-support

      # nixorcist CLI wrapper
      (pkgs.writeShellScriptBin "nixorcist" ''
        exec /etc/nixos/nixorcist/nixorcist.sh "$@"
      '')

      # Package toggle tooling
      # Usage: nixos-comment discord   → disables discord system-wide
      #        nixos-uncomment discord → re-enables it
      (pkgs.writeShellScriptBin "nixos-comment" ''
        set -euo pipefail
        FILE="/etc/nixos/packages/disabled/disabled-packages.nix"
        PKG="$1"
        if [[ -z "$PKG" ]]; then echo "Usage: nixos-comment <package>"; exit 1; fi
        grep -q "\"$PKG\"" "$FILE" && { echo "[!] $PKG already disabled"; exit 0; }
        sed -i "/\[/a\  \"$PKG\"" "$FILE"
        echo "[✓] Disabled $PKG"
        echo "[*] Run: nixos-smart-rebuild"
      '')

      (pkgs.writeShellScriptBin "nixos-uncomment" ''
        set -euo pipefail
        FILE="/etc/nixos/packages/disabled/disabled-packages.nix"
        PKG="$1"
        if [[ -z "$PKG" ]]; then echo "Usage: nixos-uncomment <package>"; exit 1; fi
        sed -i "/\"$PKG\"/d" "$FILE"
        echo "[✓] Enabled $PKG"
        echo "[*] Run: nixos-smart-rebuild"
      '')

      (pkgs.writeShellScriptBin "nixos-smart-rebuild" ''
        exec /etc/nixos/scripts/nix-rebuild-smart.sh "$@"
      '')
    ];


  # ===========================================================================
  # 🤖 GITHUB COPILOT CLI
  # ===========================================================================
  # Activation script always runs so it can also clean up when disabled.
  #
  system.activationScripts.copilot-cli.text = ''
    SENTINEL="/var/lib/copilot-cli/.installed"
    BINARY="/usr/local/bin/copilot"

    if [ "${lib.boolToString features.copilot}" = "true" ]; then
      if [ ! -f "$SENTINEL" ]; then
        echo "[*] Installing GitHub Copilot CLI..."
        mkdir -p /var/lib/copilot-cli
        ${pkgs.curl}/bin/curl -fsSL https://gh.io/copilot-install | ${pkgs.bash}/bin/bash
        touch "$SENTINEL"
        echo "[✓] GitHub Copilot CLI installed."
      fi
    else
      if [ -f "$SENTINEL" ] || [ -f "$BINARY" ]; then
        echo "[*] Removing GitHub Copilot CLI..."
        rm -f "$BINARY"
        rm -rf /var/lib/copilot-cli
        echo "[✓] GitHub Copilot CLI removed."
      fi
    fi
  '';


  # ===========================================================================
  # 🧾 STATE VERSION
  # ===========================================================================
  # DO NOT CHANGE unless you are doing a NixOS release upgrade and know
  # exactly what stateful things will be migrated.
  #
  system.stateVersion = "25.11";

}
