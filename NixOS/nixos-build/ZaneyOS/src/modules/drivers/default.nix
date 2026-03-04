{ lib, config, ... }:

let
  src = /etc/nixos/ZaneyOS/src;
  profile = config.zaneyos.profile;
in
{
  options.zaneyos.profile = lib.mkOption {
    type = lib.types.enum [ "intel" "amd" "nvidia" "nvidia-laptop" "vm" ];
    default = "intel";
  };

  imports = [
    (src + "/profiles/${profile}")
  ];
}
