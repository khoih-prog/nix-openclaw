{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.4.15";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.4.15/OpenClaw-2026.4.15.zip";
    hash = "sha256-n27rT1/ZPY6hBgVgLLG0eqKGlNuRYI8slFgb0GWCiLs=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/openclaw-app-install.sh}";

  meta = with lib; {
    description = "OpenClaw macOS app bundle";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
