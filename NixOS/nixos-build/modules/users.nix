# users.nix
{ config, pkgs, ... }:

{
  users.users.nixos = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Default Name";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
      pkgs.zsh
    ];
  };
}
