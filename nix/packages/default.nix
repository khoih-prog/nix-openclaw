{
  pkgs,
  sourceInfo ? import ../sources/openclaw-source.nix,
  openclawToolPkgs ? { },
  qmdPackage ? null,
  toolNamesOverride ? null,
  excludeToolNames ? [ ],
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  toolSets = import ../tools/extended.nix {
    pkgs = pkgs;
    openclawToolPkgs = openclawToolPkgs;
    inherit toolNamesOverride excludeToolNames;
  };
  openclawGateway = pkgs.callPackage ./openclaw-gateway.nix {
    inherit sourceInfo;
    pnpmDepsHash = sourceInfo.pnpmDepsHash or null;
  };
  openclawApp = if isDarwin then pkgs.callPackage ./openclaw-app.nix { } else null;
  openclawBundle = pkgs.callPackage ./openclaw-batteries.nix {
    openclaw-gateway = openclawGateway;
    openclaw-app = openclawApp;
    extendedTools = toolSets.tools;
    inherit qmdPackage;
    version = sourceInfo.releaseVersion or null;
  };
in
{
  openclaw-gateway = openclawGateway;
  openclaw = openclawBundle;
}
// (if qmdPackage != null then { qmd = qmdPackage; } else { })
// (if isDarwin then { openclaw-app = openclawApp; } else { })
