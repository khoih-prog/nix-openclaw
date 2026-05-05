{
  lib,
  stdenvNoCC,
  openclawPackage,
  qmdPackage ? null,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-qmd-runtime";
  version = lib.getVersion openclawPackage;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  env = {
    OPENCLAW_PACKAGE = openclawPackage;
    QMD_PACKAGE = lib.optionalString (qmdPackage != null) "${qmdPackage}";
  };

  doCheck = true;
  checkPhase = "${../scripts/check-openclaw-qmd-runtime.sh}";
  installPhase = "${../scripts/empty-install.sh}";
}
