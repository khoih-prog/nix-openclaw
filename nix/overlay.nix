{
  openclawToolPkgs ? { },
  qmdPkgs ? { },
}:
final: prev:
let
  packages = import ./packages {
    pkgs = prev;
    openclawToolPkgs = openclawToolPkgs;
    qmdPackage = qmdPkgs.qmd or qmdPkgs.default or null;
  };
  toolNames =
    (import ./tools/extended.nix {
      pkgs = prev;
      openclawToolPkgs = openclawToolPkgs;
    }).toolNames;
  withTools =
    {
      toolNamesOverride ? null,
      excludeToolNames ? [ ],
    }:
    import ./packages {
      pkgs = prev;
      openclawToolPkgs = openclawToolPkgs;
      qmdPackage = qmdPkgs.qmd or qmdPkgs.default or null;
      inherit toolNamesOverride excludeToolNames;
    };
in
packages
// {
  openclawPackages = packages // {
    inherit toolNames withTools;
  };
}
