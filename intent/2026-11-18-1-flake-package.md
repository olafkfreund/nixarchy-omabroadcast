---
status: approved
issue: 1
author: olafkfreund
---

# Intent: Package OmaBroadcast as a Nix flake with nightly upstream updates

## Problem

[OmaBroadcast](https://github.com/28allday/omabroadcast) (record, stream and
compose live video on Omarchy; MIT app, C++/Qt 6 Quick, qmake) ships only as an
Arch PKGBUILD and a `./bin/install` script. There is no way to install it on
NixOS/Nixarchy (no Nix package exists in nixpkgs or elsewhere that I found), and nothing keeps a Nix package in step with upstream, which
is young (0.1.0, 2026-11-14) and will move fast.

## Proposed outcome

- This public repo (`olafkfreund/nixarchy-omabroadcast`) is a flake that
  exposes `packages.x86_64-linux.omabroadcast` (default), runnable with
  `nix run github:olafkfreund/nixarchy-omabroadcast`, plus a module so a NixOS
  host can enable it with one option.
- The app launches from the launcher (desktop file + icon) and works on
  Hyprland: preview, screen share via the portal, recording to a file.
- A GitHub Actions workflow runs every night, checks upstream `main`, and when
  it moved, updates the pinned rev/hash in the flake, builds it, and lands
  the update on `main` only if the build and an automated smoke check
  (binary starts offscreen, links its FFmpeg) pass. Hardware behaviour
  (capture, encode, portal) is verified by hand on p620, not by CI; the
  previous good rev stays one `git revert` / `flake.lock` pin away.
- OmaBroadcast is installed on p620 and verified there by hand.

## Affected users and systems

- New repo `olafkfreund/nixarchy-omabroadcast` (public, already created).
- p620 (this machine): `~/.config/nixos` gains a flake input and enables the
  package for the p620 host only. No change to p510 or razer.
- GitHub Actions minutes on the public repo (free).

## Constraints

- x86_64-linux only as the initial target (upstream's PKGBUILD is x86_64 only).
- Upstream builds and bundles its own patched FFmpeg 9.1 (two patches in
  `pkgbuild/ffmpeg/`); nixpkgs has FFmpeg 9.0.2. The package must give the app
  an FFmpeg it actually works with.
- Licence: the carried FFmpeg is built GPL v3 with x264/x265 (per the
  PKGBUILD), so `meta.license` must reflect the combined licence, not just
  MIT. Exact expression checked in the spec.
- The build must run in the normal Nix sandbox: every source (app, FFmpeg,
  model weights, anything `./bin/build` would download) pinned by hash;
  upstream's `./bin/build` network fetches replaced by Nix fetchers.
- Nightly job must never push a broken flake: build gate before commit.
- No secrets beyond the default `GITHUB_TOKEN`, and the step that builds
  upstream code runs without a write token (upstream code is untrusted).
- CI must fit a free GitHub runner (disk, ~6 h job limit) from a cold
  cache: Qt/WebEngine must come from cache.nixos.org, only FFmpeg and the
  app built. "Nightly" is best-effort cron, not a freshness guarantee.
- p620 rebuild is a switch of the running desktop: done by me in this session
  with the owner's go-ahead, with rollback available via the previous
  generation.

## Open questions

1. FFmpeg: build upstream's patched FFmpeg 9.1 inside the derivation (faithful,
   slow build) or use nixpkgs FFmpeg 9.0.2 with upstream's two patches applied
   (may lack 9.1 APIs the app uses)? Both are FFmpeg rebuilds either way.
   Recommend: decide in the spec after checking which FFmpeg APIs the app
   calls; the test is capture + recording on p620, not just compiling.
2. Track upstream `main` commits nightly, or only release tags? Recommend:
   `main` (only one release exists so far).
3. Nightly update: commit straight to `main` after a green build, or open a PR?
   Recommend: direct commit to `main` by a separate job that only holds the
   write token and never runs upstream code (you asked for it to "update the
   flake"). A PR per update is the safer alternative if you want a human gate.
4. Install on p620 via `~/.config/nixos` flake input (permanent, needs a commit
   there) or `nix profile install` (quick test only)? Recommend: flake input,
   p620 host only.
5. Scope of "works": recording, streaming (RTMP/SRT), scene composition and
   the WebEngine browser source all in scope, or recording + preview only
   for the first cut? Recommend: everything the upstream build includes, but
   acceptance tested on recording, preview and screen share.
