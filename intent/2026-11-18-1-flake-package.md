---
status: draft
issue: 1
author: olafkfreund
---

# Intent: Package OmaBroadcast as a Nix flake with nightly upstream updates

## Problem

[OmaBroadcast](https://github.com/28allday/omabroadcast) (record, stream and
compose live video on Omarchy; MIT app, C++/Qt 6 Quick, qmake) ships only as an
Arch PKGBUILD and a `./bin/install` script. There is no way to install it on
NixOS/Nixarchy, and nothing keeps a Nix package in step with upstream, which
is young (0.1.0, 2026-11-14) and will move fast.

## Proposed outcome

- This public repo (`olafkfreund/nixarchy-omabroadcast`) is a flake that
  exposes `packages.x86_64-linux.omabroadcast` (default), runnable with
  `nix run github:olafkfreund/nixarchy-omabroadcast`, plus a module so a NixOS
  host can enable it with one option.
- The app launches from the launcher (desktop file + icon) and works on
  Hyprland: preview, screen share via the portal, recording to a file.
- A GitHub Actions workflow runs every night, checks upstream `main`, and when
  it moved, updates the pinned rev/hash in the flake, builds it, and commits
  the update to `main` only if the build passes.
- OmaBroadcast is installed on p620 and verified there by hand.

## Affected users and systems

- New repo `olafkfreund/nixarchy-omabroadcast` (public, already created).
- p620 (this machine): `~/.config/nixos` gains a flake input and enables the
  package for the p620 host only. No change to p510 or razer.
- GitHub Actions minutes on the public repo (free).

## Constraints

- x86_64-linux only (upstream's own limit: nasm, NVIDIA encoders).
- Upstream builds and bundles its own patched FFmpeg 9.1 (two patches in
  `pkgbuild/ffmpeg/`); nixpkgs has FFmpeg 9.0.2. The package must give the app
  an FFmpeg it actually works with.
- The bundled FFmpeg is GPL-3.0 with x264/x265; the flake must state the
  combined licence, not just MIT.
- Nightly job must never push a broken flake: build gate before commit.
- No secrets beyond the default `GITHUB_TOKEN`.
- p620 rebuild is a switch of the running desktop: done by me in this session
  with the owner's go-ahead, with rollback available via the previous
  generation.

## Open questions

1. FFmpeg: build upstream's patched FFmpeg 9.1 inside the derivation (faithful,
   slow build) or use nixpkgs FFmpeg 9.0.2 with upstream's two patches applied
   (faster, may break if the app needs 9.1 APIs)? Recommend: try nixpkgs+patches
   first, fall back to the carried build if it fails.
2. Track upstream `main` commits nightly, or only release tags? Recommend:
   `main` (only one release exists so far).
3. Nightly update: commit straight to `main` after a green build, or open a PR?
   Recommend: direct commit (you asked for it to "update the flake").
4. Install on p620 via `~/.config/nixos` flake input (permanent, needs a commit
   there) or `nix profile install` (quick test only)? Recommend: flake input,
   p620 host only.
