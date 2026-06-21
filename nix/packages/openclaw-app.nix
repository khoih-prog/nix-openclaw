{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.6.9";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.6.9/OpenClaw-2026.6.9.zip";
    hash = "sha256-utNrpCAXgOVcBkPb6/94sVsawgwR2jI10iuVvqwdDHU=";
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
