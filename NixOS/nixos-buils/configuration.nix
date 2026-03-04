{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # ────────────── Boot ──────────────
    ./modules/bootloader.nix
    ./modules/grub-theme.nix
    ./modules/kernel-params.nix

    # ────────────── Display & WM ──────────────
    ./modules/sddm.nix
    ./modules/window-managers.nix

    # ────────────── System Core ──────────────
    ./modules/locale.nix
    ./modules/networking.nix
    ./modules/users.nix
    ./modules/audio.nix
#    ./external/home-manager/nixos
#    ./ZaneyOS/zaneyos/default.nix
    ./modules/environment.nix
    ./modules/zsh.nix
#    ./nixorcist/generated/all-packages.nix   <---This is the correct import, but yet not working good enough
  ];

  # ────────────── GRUB Theming ──────────────

    # ────────────── ZaneyOS Layer ──────────────

#  zaneyos = {
#    enable = true;         # master switch

#    driver = "intel";          # "amd" | "nvidia" | "intel" | "vm"
#    display.enable = false; # greetd etc
#    core.enable = false;    # selected core modules
#  };

    # ────────────── Fonts ──────────────

  fonts = {
    fontDir.enable = true;

    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];
  };


  #---------------HOME MANAGER ------------------#
    
#home-manager.users.tak_1 = {
#  home.stateVersion = "24.05";

#  home.file.".config/hypr".source =
#    /home/tak_1/Hyprland-Dots/config/hypr;

#  home.file.".config/waybar".source =
#    /home/tak_1/Hyprland-Dots/config/waybar;

#  home.file.".config/kitty".source =
#    /home/tak_1/Hyprland-Dots/config/kitty;

#  home.file.".config/rofi".source =
#    /home/tak_1/Hyprland-Dots/config/rofi;

  # etc.
#};
  # ────────────── Graphics & Gaming ──────────────

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  services.pipewire.enable = true;
  
  qt = {
    enable = true;
    platformTheme = "kde";
  };
  
	services.openssh = {
	  enable = true;
	  settings = {
	    PermitRootLogin = "no";
	    PasswordAuthentication = true;
	  };
	};

  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.hyprland.enable = true;
  programs.gamemode.enable = true;

  # ────────────── Global Options ──────────────

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = "nix-command flakes";

  

	systemd.user.services.polkit-kde-agent = {
	  description = "Polkit KDE Authentication Agent";
	  after = [ "hyprland-session.target" ];
	  wantedBy = [ "hyprland-session.target" ];
	  serviceConfig = {
	    ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
	    Restart = "on-failure";
	  };
	};


   
  environment.etc."xdg/menus/applications.menu".source =
      "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
  environment.systemPackages =
    (import ./packages/all-packages.nix { inherit pkgs; })++
#    (import ./nixorcist/generated/all-packages.nix { inherit pkgs; })++
      [
      pkgs.kdePackages.polkit-kde-agent-1

      (pkgs.writeShellScriptBin "nixorcist" ''
        exec /etc/nixos/nixorcist/nixorcist.sh "$@"
      '')
  ];



  system.stateVersion = "25.11";
}
