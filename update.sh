#!/usr/bin/env bash
set -euo pipefail

sources=${SOURCES:-sources.json}
rev=$(git ls-remote https://github.com/28allday/omabroadcast refs/heads/main | cut -f1)
[[ $rev =~ ^[0-9a-f]{40}$ ]] || { echo 'invalid upstream revision' >&2; exit 1; }

if [[ $rev == "$(jq -r '.rev' "$sources")" ]]; then
  echo 'up to date'
  exit 0
fi

prefetch=$(nix flake prefetch "github:28allday/omabroadcast/$rev" --json)
hash=$(jq -r '.hash' <<<"$prefetch")
store_path=$(jq -r '.storePath' <<<"$prefetch")
commit=$(sed -nE 's/^COMMIT=([0-9a-f]{40})([[:space:]].*)?$/\1/p' "$store_path/bin/build-ffmpeg")
pkgver=$(sed -nE 's/^pkgver=(.*)$/\1/p' "$store_path/pkgbuild/PKGBUILD")
pkgrel=$(sed -nE 's/^pkgrel=(.*)$/\1/p' "$store_path/pkgbuild/PKGBUILD")

[[ $hash =~ ^sha256-[A-Za-z0-9+/]{43}=$ && $commit =~ ^[0-9a-f]{40}$ && $pkgver =~ ^[0-9]+(\.[0-9]+)*$ && $pkgrel =~ ^[0-9]+$ ]] || {
  echo 'invalid upstream pins' >&2
  exit 1
}

ffmpeg_hash=$(jq -r '.ffmpeg.hash' "$sources")
if [[ $commit != "$(jq -r '.ffmpeg.rev' "$sources")" ]]; then
  ffmpeg_hash=$(nix flake prefetch "github:FFmpeg/FFmpeg/$commit" --json | jq -r '.hash')
fi
[[ $ffmpeg_hash =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]] || { echo 'invalid FFmpeg hash' >&2; exit 1; }

jq -n --arg version "$pkgver-$pkgrel" --arg rev "$rev" --arg hash "$hash" \
  --arg ffmpeg_rev "$commit" --arg ffmpeg_hash "$ffmpeg_hash" \
  '{version: $version, rev: $rev, hash: $hash, ffmpeg: {rev: $ffmpeg_rev, hash: $ffmpeg_hash}}' > "$sources"
echo "updated to ${rev:0:12}"
