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
    # Portal and PipeWire stay host-managed: defaulting them on breaks hosts with no
    # portal backend (assertion) or with PulseAudio. See README prerequisites.
    environment.systemPackages = [ cfg.package ];
  };
}
