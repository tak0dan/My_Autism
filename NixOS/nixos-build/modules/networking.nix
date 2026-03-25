{ config, pkgs, ... }:

{
  networking.hostName = "Deffault_Name";
  networking.networkmanager.enable = true;
}
