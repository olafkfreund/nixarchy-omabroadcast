---
status: draft
issue: 1
spec: spec/2026-11-18-1-flake-package.md
coders:
  1: coder   # flake skeleton + pins: plain Nix, follows the spec's table
  2: coder   # FFmpeg derivation: Nix, iterated against my builds
  3: coder   # app derivation: Nix, iterated against my builds
  4: coder   # module + checks: small, plain Nix
  5: codex   # update.sh: small tricky logic (static parsing, validation regexes)
  6: codex   # workflows: small, security-sensitive (token split, artifact validation)
  7: coder   # README: prose
reviewers:
  - codex    # independent read-only review of the full diff before the PR
  # agy omitted: out of use by owner decision (#2748)
---

# Plan: Package OmaBroadcast as a Nix flake with nightly upstream updates

## Approved decisions (self-contained)

- Repo `olafkfreund/nixarchy-omabroadcast` (public), branch
  `feat/1-flake-package`, issue #1. x86_64-linux only.
- Track upstream `28allday/omabroadcast` `main`. Initial pins:
  app rev `827031aa091e13d77d7139107a20e1f14b50e020`,
  hash `sha256-vi++8Vg0bSeKTn7vaSkDBWjnHK23Q4NLm6O+S8PW83M=`, version `0.1.0-62`;
  FFmpeg rev `47b92841e33b67c1699394415641b34d1157d8d7`,
  hash `sha256-dpMiqPJ1aTFZ0HA2PbtzDmvJ2+ZrpWqXec04uA0O2fE=`.
- Our own FFmpeg 9.1 derivation (needed for the Vulkan APV encoder). Both
  upstream patches in `pkgbuild/ffmpeg/*.patch` apply, sorted, mandatory
  (0001 is needed because WebEngine loads into the app process).
  Configure flags are **read at build time** from the `FLAGS="…"` block in
  upstream `bin/build-ffmpeg` with `sed` (never sourced), `--prefix=…`
  replaced by `--prefix=$out`.
- App built with qmake directly (not `bin/build`): `sh bin/shaders`, qmake
  `CONFIG+=packaged`, then `browser/`. Helper in
  `$out/libexec/omabroadcast/`, found via wrapper
  `--set OMABROADCAST_BROWSER_HELPER`; `slurp` on PATH; `hyprctl`/`omarchy`
  from the host.
- NixOS module `programs.omabroadcast.{enable,package}`.
- Nightly: job `update` (contents: read) runs `update.sh` + `nix flake
  check`, uploads `sources.json`; job `commit` (contents: write) validates it
  and pushes only `sources.json` to `main`. Direct commit, no PR.
- p620: flake input + `hosts/p620/nixos/omabroadcast.nix`; switch on p620 only.

## Steps

1. `flake.nix`, `sources.json` (new): inputs `nixpkgs =
   github:nixos/nixpkgs/nixos-unstable`. `let sources = lib.importJSON
   ./sources.json; pkgs = nixpkgs.legacyPackages.x86_64-linux;` outputs
   `packages.x86_64-linux = { ffmpeg-omabroadcast = pkgs.callPackage
   ./nix/ffmpeg.nix { inherit sources appSrc; }; omabroadcast =
   pkgs.callPackage ./nix/package.nix { … }; default = omabroadcast; }`,
   `formatter = pkgs.nixfmt-rfc-style`. `appSrc = pkgs.fetchFromGitHub {
   owner = "28allday"; repo = "omabroadcast"; inherit (sources) rev hash; }`.
   `sources.json` = the initial pins above, keys exactly
   `version, rev, hash, ffmpeg.rev, ffmpeg.hash`.
   → verify by `nix flake show` (after `git add`).
   Traps: flakes only see git-tracked files, so `git add` new files first.

2. `nix/ffmpeg.nix` (new): as decided. `pname = "ffmpeg-omabroadcast"`,
   `version = "9.1"`, src `fetchFromGitHub { owner = "FFmpeg"; repo =
   "FFmpeg"; inherit (sources.ffmpeg) rev hash; }`. `patches =
   map (n: "${appSrc}/pkgbuild/ffmpeg/${n}") (sort lessThan (filter
   (hasSuffix ".patch") (attrNames (readDir "${appSrc}/pkgbuild/ffmpeg"))))`.
   `configurePhase`: `flags=$(sed -n '/^FLAGS="/,/"$/p' ${appSrc}/bin/build-ffmpeg
   | sed 's/^FLAGS="//; s/"$//' | tr '\n' ' ' | sed 's/--prefix=[^ ]*//')`;
   `./configure --prefix=$out $flags` (no `--disable-programs` removal; upstream
   disables them). Inputs as in the spec: nativeBuildInputs nasm pkg-config
   clang glslang; buildInputs x264 x265 svt-av1 libaom dav1d libvpx srt
   libopus snappy gnutls bzip2 xz zlib libdrm libva vulkan-headers
   vulkan-loader nv-codec-headers-12. `enableParallelBuilding = true`,
   `meta.license = lib.licenses.gpl3Plus`.
   → verify by `nix build .#ffmpeg-omabroadcast -L` and
   `grep -a -c apv_vulkan result/lib/libavcodec.so.*` ≥ 1.
   Traps: `readDir` on a fetcher output is IFD; fine locally and in CI
   (no `--no-allow-import-from-derivation`). Shell vars in Nix strings:
   escape as `''${…}`. If `--enable-cuda-llvm` fails, check clang is the
   unwrapped one FFmpeg probes (`clang` on PATH); do not drop the flag
   without updating this plan.

3. `nix/package.nix` (new): `stdenv.mkDerivation { pname = "omabroadcast";
   version = sources.version; src = appSrc; }`. nativeBuildInputs
   `qt6.qmake qt6.wrapQtAppsHook qt6.qttools pkg-config glslang
   wayland-scanner`; buildInputs qtbase qtdeclarative qtwebengine qtwayland
   qtsvg qtimageformats qtpositioning qtwebchannel rnnoise vulkan-headers
   vulkan-loader pipewire wayland mesa libdrm ffmpeg-omabroadcast.
   `dontUseQmakeConfigure = true`; `buildPhase`: `sh bin/shaders; mkdir build
   && cd build && qmake ../omabroadcast.pro CONFIG+=packaged && make
   -j$NIX_BUILD_CORES && mkdir browser && (cd browser && qmake
   ../../browser/omabroadcast-browser.pro && make -j$NIX_BUILD_CORES)`.
   `installPhase`: `install -Dm755 build/omabroadcast $out/bin/omabroadcast`;
   `install -Dm755 build/browser/omabroadcast-browser
   $out/libexec/omabroadcast/omabroadcast-browser`; desktop file and svg from
   `pkgbuild/` to `share/applications`, `share/icons/hicolor/scalable/apps`;
   licences (`LICENSE`, `THIRD_PARTY.md`, `src/ui/icons/LICENSE.lucide`,
   `src/engine/models/LICENSE.MODNet`, `${ffmpeg-omabroadcast.src}/COPYING.GPLv3`)
   to `share/licenses/omabroadcast/`. `doInstallCheck = true`;
   `installCheckPhase`: `test -x $out/libexec/omabroadcast/omabroadcast-browser`.
   `qtWrapperArgs = [ "--set OMABROADCAST_BROWSER_HELPER
   $out/libexec/omabroadcast/omabroadcast-browser" "--prefix PATH :
   ${lib.makeBinPath [ slurp ]}" ]` (set in `preFixup` so `$out` expands).
   meta per spec.
   → verify by `nix build .#omabroadcast -L`, then
   `ldd result/bin/.omabroadcast-wrapped | grep libavcodec` shows
   `ffmpeg-omabroadcast`.
   Traps: build in a writable copy (default unpackPhase does this;
   `bin/shaders` writes `src/engine/shaders/gen`). `omabroadcast.pro` reads
   `pkgbuild/PKGBUILD` via `sed` (needs `sed` on PATH: stdenv has it).
   wrapQtAppsHook wraps `bin` and `libexec`.

4. `nix/module.nix` (new), `flake.nix` (edit): module as spec:
   `options.programs.omabroadcast = { enable = mkEnableOption "OmaBroadcast";
   package = mkOption { type = types.package; default =
   self.packages.${pkgs.stdenv.hostPlatform.system}.omabroadcast; }; }`;
   config: `environment.systemPackages = [ cfg.package ]`,
   `xdg.portal.enable = mkDefault true`, `services.pipewire = { enable =
   mkDefault true; pulse.enable = mkDefault true; }`. Flake:
   `nixosModules.default = import ./nix/module.nix self`;
   `checks.x86_64-linux = { build = omabroadcast; probe = pkgs.runCommand
   "omabroadcast-probe" {} ''…''; }` where probe runs
   `HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR QT_QPA_PLATFORM=offscreen
   ${omabroadcast}/bin/omabroadcast --probe`,
   `ldd ${omabroadcast}/bin/.omabroadcast-wrapped | grep -q ffmpeg-omabroadcast`,
   `grep -a -q apv_vulkan ${ffmpeg-omabroadcast}/lib/libavcodec.so.*`,
   `${omabroadcast}/libexec/omabroadcast/omabroadcast-browser --check`, then
   `touch $out`.
   → verify by `nix flake check -L`.
   Traps: `--probe` needs no display; if it fails in the sandbox on missing
   `/dev/dri` or D-Bus, record what it printed and make only the failing part
   tolerant, noted here as a deviation.

5. `update.sh` (new, executable, `set -euo pipefail`): as spec. `git
   ls-remote https://github.com/28allday/omabroadcast refs/heads/main`; same
   rev as `sources.json` → print "up to date", exit 0. Else `nix flake
   prefetch github:28allday/omabroadcast/$rev --json` → `hash`, `storePath`;
   from `$storePath/bin/build-ffmpeg` read `^COMMIT=([0-9a-f]{40})` and from
   `$storePath/pkgbuild/PKGBUILD` `^pkgver=` and `^pkgrel=` with `sed -nE`
   only; validate rev `^[0-9a-f]{40}$`, pkgver `^[0-9]+(\.[0-9]+)*$`,
   pkgrel `^[0-9]+$`, hashes `^sha256-[A-Za-z0-9+/]{43}=$`; if FFmpeg rev
   differs, prefetch `github:FFmpeg/FFmpeg/$commit`; write `sources.json`
   via `jq -n` with `--arg`; print the new short rev. Never `source`/`eval`
   upstream files.
   → verify by `./update.sh` (no-op now), then set `rev` to 40 zeros in a
   scratch copy, run it, `git diff` shows only the real rev back.
   Traps: `shellcheck update.sh` clean.

6. `.github/workflows/update.yml`, `.github/workflows/ci.yml` (new): as spec.
   update.yml: `on: schedule: cron "0 3 * * *"` + `workflow_dispatch`;
   `concurrency: update`; job `update` `permissions: contents: read`,
   steps: checkout, `DeterminateSystems/nix-installer-action`, `./update.sh`
   (sets `changed` output by comparing `git diff --quiet sources.json`),
   `nix flake check -L` if changed, `actions/upload-artifact` name
   `sources-${{ github.run_id }}` path `sources.json`. Job `commit`:
   `needs: update`, `if: needs.update.outputs.changed == 'true'`,
   `permissions: contents: write`, checkout, `actions/download-artifact`
   (same name) to `$RUNNER_TEMP/a`, `jq -e` validation (exact key set,
   strings, regexes from step 5), `cp` over `sources.json`, `git add
   sources.json`, commit as `github-actions[bot]` with rev from `env:`,
   push. ci.yml: on `push`/`pull_request`, nix installer + `nix flake check -L`.
   All `uses:` pinned to full commit SHAs (look up current tags with
   `gh api repos/<owner>/<repo>/git/ref/tags/<tag>`).
   → verify by `actionlint` (`nix run nixpkgs#actionlint`).
   Traps: never put `${{ … }}` artifact/upstream values inside `run:`
   scripts; pass through `env:`.

7. `README.md` (edit): what it is, `nix run github:olafkfreund/nixarchy-omabroadcast`,
   flake input + `programs.omabroadcast.enable = true`, prerequisites
   (Hyprland with `hyprctl`, xdg-desktop-portal-hyprland, PipeWire + Pulse,
   a Secret Service such as gnome-keyring, Vulkan/VA-API drivers), licence
   note (MIT app, GPL-3.0 FFmpeg build), nightly update policy.
   → verify by reading.

8. Mine: local build and checks on p620 — `nix flake check -L`,
   `nix run .#omabroadcast -- --probe`, record build times. Commit per step
   as `feat: …` / `ci: …` with `(#1)`.

9. Mine: Codex read-only review of `git diff main...` (reviewers above),
   fix confirmed findings, open the PR linking intent/spec/plan, wait for
   `ci.yml` green, merge to `main` (workflow_dispatch needs the workflow on
   the default branch).

10. Mine: on `main`, `gh workflow run update.yml` → no-op green. Then commit
    a stale `rev` (40 zeros) to `sources.json` on `main`, dispatch again →
    it re-pins, builds and pushes one commit restoring the real rev. Record
    cold-run time and peak disk (a `df -h /` step) in the PR/issue.

11. Mine, `~/.config/nixos` (owner's repo; plan approval = go-ahead for
    p620 only): branch `feat/omabroadcast-p620` there. `flake.nix`: input
    `nixarchy-omabroadcast = { url = "github:olafkfreund/nixarchy-omabroadcast";
    inputs.nixpkgs.follows = "nixpkgs"; };` next to `nixarchy-pixelbuds`.
    New `hosts/p620/nixos/omabroadcast.nix`:
    `{ inputs, ... }: { imports = [ inputs.nixarchy-omabroadcast.nixosModules.default ];
    programs.omabroadcast.enable = true; }`, added to the `imports` list in
    `hosts/p620/configuration.nix` (lines 15-30, after `./nixos/nixarchy.nix`). `nix flake lock --update-input
    nixarchy-omabroadcast`, `nixos-rebuild build --flake .#p620`, then
    `sudo nixos-rebuild switch --flake .#p620`. Commit there.
    → verify by `which omabroadcast`, `omabroadcast --probe`.
    Traps: no change to p510/razer; follow that repo's own rules
    (its `AGENTS.md`) for branch, issue and commit format.

12. Owner, by hand on p620 (I launch the app and report what I can see):
    launcher entry; screen source via the portal picker; 10 s recording
    plays back; a browser source loads a page; a custom browser dock opens.

## Tests

| Check | Expected |
| ----- | -------- |
| `nix flake check -L` | passes (build + probe) |
| `nix run .#omabroadcast -- --probe` | exit 0, lists GPU and encoders |
| `actionlint`, `shellcheck update.sh` | clean |
| `ci.yml` on PR | green |
| `update.yml` dispatch, no change | green, no commit |
| `update.yml` dispatch, stale rev | green, one commit to `main` |
| p620 manual (step 12) | all five items work |

## Rollback

- This repo: revert the commits on `main`, or disable `update.yml`
  (`gh workflow disable update.yml`).
- p620: `sudo nixos-rebuild switch --rollback`, then revert the
  `~/.config/nixos` branch commit (not merged to its main without the owner).
