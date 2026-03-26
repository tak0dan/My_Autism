{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.gpu-profiles.thinkpad-t480;
in
{
  options.gpu-profiles.thinkpad-t480 = {
    enable = mkEnableOption "ThinkPad T480 kernel parameters and Intel GPU tuning";
  };

  config = mkIf cfg.enable {

    boot.kernel.sysctl = {
      "kernel.sysrq" = 1;
      "kernel.panic" = 10;
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    # Intel GPU tuning (T480)
    boot.kernelParams = [
      "i915.enable_guc=3"
      "i915.fastboot=1"
      "i915.enable_fbc=1"
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.cpu.intel.updateMicrocode = true;

    services.power-profiles-daemon.enable = true;
    services.tlp.enable = false;

    hardware.enableRedistributableFirmware = true;
  };
}
