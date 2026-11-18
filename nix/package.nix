{
  lib,
  stdenv,
  qt6,
  pkg-config,
  glslang,
  wayland-scanner,
  rnnoise,
  vulkan-headers,
  vulkan-loader,
  pipewire,
  wayland,
  mesa,
  libgbm,
  libdrm,
  slurp,
  sources,
  appSrc,
  ffmpeg-omabroadcast,
}:

stdenv.mkDerivation {
  pname = "omabroadcast";
  version = sources.version;
  src = appSrc;

  nativeBuildInputs = [
    qt6.qmake
    qt6.wrapQtAppsHook
    qt6.qttools
    pkg-config
    glslang
    wayland-scanner
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwebengine
    qt6.qtwayland
    qt6.qtsvg
    qt6.qtimageformats
    qt6.qtpositioning
    qt6.qtwebchannel
    rnnoise
    vulkan-headers
    vulkan-loader
    pipewire
    wayland
    mesa
    libgbm # wayland.pri asks pkg-config for gbm; it is its own package now
    libdrm
    ffmpeg-omabroadcast
  ];

  dontUseQmakeConfigure = true;

  # Subshells keep the phase in the source root. Mirrors bin/build without its
  # CONFIG+=carried_ffmpeg: the Nix FFmpeg is found through pkg-config.
  buildPhase = ''
    runHook preBuild
    sh bin/shaders
    mkdir -p build/browser
    # qtwebengine propagates nixpkgs' FFmpeg 9.0.2 with the same sonames (.so.63):
    # put ours first for pkg-config and first in RUNPATH, or the app runs on 9.0.2.
    (cd build && PKG_CONFIG_PATH=${ffmpeg-omabroadcast}/lib/pkgconfig:$PKG_CONFIG_PATH \
      qmake ../omabroadcast.pro CONFIG+=packaged "QMAKE_LFLAGS+=-Wl,-rpath,${ffmpeg-omabroadcast}/lib" \
      && make -j$NIX_BUILD_CORES)
    (cd build/browser && qmake ../../browser/omabroadcast-browser.pro && make -j$NIX_BUILD_CORES)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/omabroadcast $out/bin/omabroadcast
    install -Dm755 build/browser/omabroadcast-browser $out/libexec/omabroadcast/omabroadcast-browser
    install -Dm644 pkgbuild/omabroadcast.desktop $out/share/applications/omabroadcast.desktop
    install -Dm644 pkgbuild/omabroadcast.svg $out/share/icons/hicolor/scalable/apps/omabroadcast.svg
    for f in LICENSE THIRD_PARTY.md src/ui/icons/LICENSE.lucide src/engine/models/LICENSE.MODNet; do
      install -Dm644 $f $out/share/licenses/omabroadcast/$(basename $f)
    done
    install -Dm644 ${ffmpeg-omabroadcast.src}/COPYING.GPLv3 $out/share/licenses/omabroadcast/ffmpeg/COPYING.GPLv3
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/libexec/omabroadcast/omabroadcast-browser
    runHook postInstallCheck
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --set OMABROADCAST_BROWSER_HELPER "$out/libexec/omabroadcast/omabroadcast-browser"
      --prefix PATH : "${lib.makeBinPath [ slurp ]}"
    )
  '';

  meta = {
    description = "Record, stream and compose live video on Omarchy";
    homepage = "https://github.com/28allday/omabroadcast";
    license = with lib.licenses; [
      mit
      gpl3Plus
      asl20
      isc
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "omabroadcast";
  };
}
