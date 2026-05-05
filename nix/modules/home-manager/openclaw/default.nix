{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (lib.mkRemovedOptionModule [
      "programs"
      "openclaw"
      "firstParty"
    ] "Use programs.openclaw.bundledPlugins.<name>.enable/config.")
    (lib.mkRemovedOptionModule [
      "programs"
      "openclaw"
      "plugins"
    ] "Use programs.openclaw.customPlugins.")
    ./options.nix
    ./config.nix
  ];
}
