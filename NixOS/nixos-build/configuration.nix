{ config, pkgs, ... }:

# =============================================================================
#                         Personal Modular NixOS Configuration
# =============================================================================
#
# This file serves as the central orchestration layer of the system.
# Most functionality is implemented inside modular files located in:
#
#   ./modules/
#
# The goal is to keep this file readable while delegating complexity
# to dedicated modules.
#
# =============================================================================

{

  # ===========================================================================
  #                                   Imports
  # ===========================================================================

  imports = [

    # -------------------------------------------------------------------------
    # Hardware
    # -------------------------------------------------------------------------

    ./hardware-configuration.nix


    # -------------------------------------------------------------------------
    # Boot System
    # -------------------------------------------------------------------------

    ./modules/bootloader.nix
    ./modules/grub-theme.nix
    ./modules/kernel-params.nix


    # -------------------------------------------------------------------------
    # Display Manager
    # -------------------------------------------------------------------------

    ./modules/sddm.nix


    # -------------------------------------------------------------------------
    # Window Managers / Desktop Environment
    # -------------------------------------------------------------------------

    ./modules/window-managers.nix


    # -------------------------------------------------------------------------
    # Core System Modules
    # -------------------------------------------------------------------------

    ./modules/locale.nix
    ./modules/networking.nix
    ./modules/users.nix
    ./modules/audio.nix


    # -------------------------------------------------------------------------
    # Shell / Environment
    # -------------------------------------------------------------------------

#   ./external/home-manager/nixos
#   ./ZaneyOS/zaneyos/default.nix

    ./modules/environment.nix
    ./modules/zsh.nix


    # -------------------------------------------------------------------------
    # Generated packages (Nixorcist)
    # -------------------------------------------------------------------------

    ./nixorcist/generated/all-packages.nix

  ];



  # ===========================================================================
  #                                   Fonts
  # ===========================================================================

  fonts = {

    fontDir.enable = true;

    packages = with pkgs; [

      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only

    ];

  };



  # ===========================================================================
  #                            Graphics / Hardware
  # ===========================================================================
  #
  # Enables OpenGL stack and 32-bit compatibility required by many games
  #

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;



  # ===========================================================================
  #                               Audio (PipeWire)
  # ===========================================================================

  services.pipewire.enable = true;



  # ===========================================================================
  #                    Desktop Environment / Window Managers
  # ===========================================================================
  #
  # Hyprland Wayland compositor
  # KDE components used for integration (Qt apps, dialogs, etc.)
  #

  programs.hyprland.enable = true;

  qt = {

    enable = true;
    platformTheme = "kde";

  };



  # ===========================================================================
  #                                 Networking
  # ===========================================================================

  services.openssh = {

    enable = true;

    settings = {

      # Disable direct root login over SSH
      PermitRootLogin = "no";

      # Enable password login (consider disabling when using SSH keys)
      PasswordAuthentication = true;

    };

  };



  # ===========================================================================
  #                         Containers / Virtualisation
  # ===========================================================================

  virtualisation.docker.enable = true;



  # ===========================================================================
  #                                   Gaming
  # ===========================================================================

  programs.steam.enable = true;

  programs.steam.gamescopeSession.enable = true;

  programs.gamemode.enable = true;



  # ===========================================================================
  #                               Global Nix Options
  # ===========================================================================

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];

      download-buffer-size = 324217728;
      http-connections = 50;
  };



  # ===========================================================================
  #                                  Polkit
  # ===========================================================================
  #
  # Required for graphical authentication dialogs under Hyprland
  #

  security.polkit.enable = true;



  systemd.user.services.polkit-kde-agent = {

    description = "Polkit KDE Authentication Agent";

    after = [ "hyprland-session.target" ];
    wantedBy = [ "hyprland-session.target" ];

    serviceConfig = {

      ExecStart =
        "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";

      Restart = "on-failure";

    };

  };



  # ===========================================================================
  #                          KDE Menu Compatibility Fix
  # ===========================================================================
  #
  # Ensures KDE menu entries function correctly when using KDE applications
  # outside of a full Plasma desktop session.
  #

  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";



  # ===========================================================================
  #                               System Packages
  # ===========================================================================

  environment.systemPackages =

    (import ./packages/all-packages.nix { inherit pkgs; })

    ++ [

      pkgs.kdePackages.polkit-kde-agent-1
      pkgs.kdePackages.kio-admin
      pkgs.hyprland-qt-support


      # -----------------------------------------------------------------------
      # Nixorcist CLI entry point
      # -----------------------------------------------------------------------

      (pkgs.writeShellScriptBin "nixorcist" ''
        exec /etc/nixos/nixorcist/nixorcist.sh "$@"
      '')

    ];



  # ===========================================================================
  #                              System State Version
  # ===========================================================================
  #
  # DO NOT change unless you know what you are doing.
  # Controls compatibility defaults for NixOS services.
  #

  system.stateVersion = "25.11";

}
