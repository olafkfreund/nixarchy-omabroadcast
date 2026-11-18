# nixarchy-omabroadcast

Nix flake packaging [OmaBroadcast](https://github.com/28allday/omabroadcast)
(record, stream and compose live video on Omarchy) for NixOS / Nixarchy.
x86_64-linux only. It builds the app together with the patched FFmpeg 9.1 it
needs (Vulkan APV encoder).

## Try it

```sh
nix run github:olafkfreund/nixarchy-omabroadcast
```

## Install on NixOS

```nix
# flake.nix
inputs.nixarchy-omabroadcast = {
  url = "github:olafkfreund/nixarchy-omabroadcast";
  inputs.nixpkgs.follows = "nixpkgs";
};

# a NixOS module
{ inputs, ... }: {
  imports = [ inputs.nixarchy-omabroadcast.nixosModules.default ];
  programs.omabroadcast.enable = true;
}
```

The module only installs the package; the desktop services below are yours
to enable.

## Prerequisites

- Hyprland (`hyprctl` on PATH) and `xdg-desktop-portal-hyprland`
- PipeWire with the Pulse server
- A Secret Service, such as gnome-keyring
- Vulkan and VA-API drivers for your GPU

## Licence

The app is MIT. The bundled FFmpeg 9.1 build is GPL-3.0-or-later (it carries
x264 and x265), so the combined package is distributed under those terms.
Lucide icons are ISC and the MODNet model is Apache-2.0. Licence texts are
installed under `share/licenses/omabroadcast/`.

## Updates

A workflow runs nightly at 03:00 UTC and tracks upstream `main`. The pinned
revisions and hashes live in `sources.json`. A new pin is committed only after
`nix flake check` passes. Upstream code is built without a write token; only
`sources.json` is pushed, by a separate job.
