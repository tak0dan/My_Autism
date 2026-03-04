{ lib, config, pkgs, ... }:

{
  config = lib.mkIf (
    config.zaneyos.enable &&
    config.zaneyos.display.enable
  ) {
    services.greetd = {
      enable = true;
      vt = 3;

      settings.default_session = {
        user = config.users.users.${config.zaneyos.user}.name;
        command =
          "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      };
    };
  };
}
