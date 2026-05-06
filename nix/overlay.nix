{
  openclawToolPkgs ? { },
}:
final: prev:
let
  packages = import ./packages {
    pkgs = prev;
    openclawToolPkgs = openclawToolPkgs;
    qmdPackage = openclawToolPkgs.qmd or null;
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
      qmdPackage = openclawToolPkgs.qmd or null;
      inherit toolNamesOverride excludeToolNames;
    };
in
packages
// {
  openclawPackages = packages // {
    inherit toolNames withTools;
  };
}
