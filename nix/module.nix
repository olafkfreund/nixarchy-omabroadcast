self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omabroadcast;
in
{
  options.programs.omabroadcast = {
    enable = lib.mkEnableOption "OmaBroadcast";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.omabroadcast;
      description = "The OmaBroadcast package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    xdg.portal.enable = lib.mkDefault true;
    services.pipewire = {
      enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };
  };
}
