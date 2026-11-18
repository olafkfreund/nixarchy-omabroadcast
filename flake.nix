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

      nixosModules.default = import ./nix/module.nix self;

      checks.x86_64-linux = {
        build = omabroadcast;
        module =
          assert import ./tests/module-eval.nix self == { off = false; on = true; };
          pkgs.emptyFile;
        probe = pkgs.runCommand "omabroadcast-probe" { nativeBuildInputs = [ pkgs.glibc.bin ]; } ''
          export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR QT_QPA_PLATFORM=offscreen
          ${omabroadcast}/bin/omabroadcast --probe
          ldd ${omabroadcast}/bin/.omabroadcast-wrapped | grep -E 'lib(av|sw)' > libs
          grep -q libavcodec libs && ! grep -v ffmpeg-omabroadcast libs
          grep -a -q apv_vulkan ${ffmpeg-omabroadcast}/lib/libavcodec.so.*
          ${omabroadcast}/libexec/omabroadcast/omabroadcast-browser --check
          touch $out
        '';
      };
    };
}
