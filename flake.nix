{
  description = "OmaBroadcast (28allday/omabroadcast) packaged for Nix";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      sources = pkgs.lib.importJSON ./sources.json;
      appSrc = pkgs.fetchFromGitHub {
        owner = "28allday";
        repo = "omabroadcast";
        inherit (sources) rev hash;
      };
      ffmpeg-omabroadcast = pkgs.callPackage ./nix/ffmpeg.nix { inherit sources appSrc; };
      omabroadcast = pkgs.callPackage ./nix/package.nix {
        inherit sources appSrc ffmpeg-omabroadcast;
      };
    in
    {
      packages.x86_64-linux = {
        inherit ffmpeg-omabroadcast omabroadcast;
        default = omabroadcast;
      };

      formatter.x86_64-linux = pkgs.nixfmt-rfc-style;

      # TODO(step 4): nixosModules.default and checks.x86_64-linux go here.
    };
}
