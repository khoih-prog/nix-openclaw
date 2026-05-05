{
  lib,
  stdenv,
  nodejs_22,
  openclawGateway,
}:

stdenv.mkDerivation {
  pname = "openclaw-gateway-smoke";
  version = lib.getVersion openclawGateway;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ nodejs_22 ];

  env = {
    OPENCLAW_GATEWAY = openclawGateway;
  };

  __darwinAllowLocalNetworking = true;

  doCheck = true;
  checkPhase = "${nodejs_22}/bin/node ${../scripts/gateway-smoke.mjs}";
  installPhase = "${../scripts/empty-install.sh}";
}
