# nix eval --impure --expr 'import ./tests/module-eval.nix (builtins.getFlake (toString ./.))'
flake:
let
  nixpkgs = flake.inputs.nixpkgs;
  pkg = flake.packages.x86_64-linux.omabroadcast;
  has =
    enable:
    let
      sys = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          flake.nixosModules.default
          {
            programs.omabroadcast.enable = enable;
            boot.loader.grub.enable = false;
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
            system.stateVersion = "25.05";
          }
        ];
      };
    in
    assert builtins.all (a: a.assertion) sys.config.assertions;
    builtins.elem pkg sys.config.environment.systemPackages;
in
{
  off = has false;
  on = has true;
}
