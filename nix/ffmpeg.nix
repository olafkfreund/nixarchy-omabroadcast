{
  lib,
  stdenv,
  fetchFromGitHub,
  sources,
  appSrc,
  nasm,
  pkg-config,
  buildPackages,
  removeReferencesTo,
  glslang,
  x264,
  x265,
  svt-av1,
  libaom,
  dav1d,
  libvpx,
  srt,
  libopus,
  snappy,
  gnutls,
  bzip2,
  xz,
  zlib,
  libdrm,
  libva,
  vulkan-headers,
  vulkan-loader,
  nv-codec-headers-12,
}:

let
  patchDir = "${appSrc}/pkgbuild/ffmpeg";
in
stdenv.mkDerivation {
  pname = "ffmpeg-omabroadcast";
  version = "9.1";

  src = fetchFromGitHub {
    owner = "FFmpeg";
    repo = "FFmpeg";
    inherit (sources.ffmpeg) rev hash;
  };

  # Both upstream patches are mandatory (0001 is needed because WebEngine loads into the app).
  patches = map (n: "${patchDir}/${n}") (
    lib.sort lib.lessThan (
      lib.filter (lib.hasSuffix ".patch") (builtins.attrNames (builtins.readDir patchDir))
    )
  );

  nativeBuildInputs = [
    nasm
    pkg-config
    glslang
    removeReferencesTo
  ];
  buildInputs = [
    x264
    x265
    svt-av1
    libaom
    dav1d
    libvpx
    srt
    libopus
    snappy
    gnutls
    bzip2
    xz
    zlib
    libdrm
    libva
    vulkan-headers
    vulkan-loader
    nv-codec-headers-12
  ];

  # Flags come from upstream's FLAGS="…" block, parsed with sed (never sourced).
  configurePhase = ''
    runHook preConfigure
    flags=$(sed -n '/^FLAGS="/,/"$/p' ${appSrc}/bin/build-ffmpeg \
      | sed 's/^FLAGS="//; s/"$//' | tr '\n' ' ' | sed 's/--prefix=[^ ]*//')
    # An empty or renamed block must not fall back to defaults.
    for f in --enable-gpl --enable-vulkan --enable-shared; do
      case " $flags " in
        *" $f "*) ;;
        *) echo "FLAGS block in bin/build-ffmpeg lacks $f: $flags" >&2; exit 1 ;;
      esac
    done
    echo "configure flags: $flags"
    # Unwrapped clang: FFmpeg retargets it freestanding for --enable-cuda-llvm (as nixpkgs' ffmpeg does).
    ./configure --prefix=$out --nvcc=${lib.getExe buildPackages.clang.cc} $flags
    remove-references-to -t ${buildPackages.clang.cc} config.h
    runHook postConfigure
  '';

  enableParallelBuilding = true;
  # Same as nixpkgs' ffmpeg with cuda-llvm (NixOS/nixpkgs#318674).
  hardeningDisable = [
    "pacret"
    "shadowstack"
    "zerocallusedregs"
  ];

  meta = {
    description = "FFmpeg 9.1 build for OmaBroadcast (Vulkan APV encoder, patched)";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
