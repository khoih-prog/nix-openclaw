{
  config,
  lib,
  pkgs,
}:

let
  cfg = config.programs.openclaw;
  homeDir = config.home.homeDirectory;
  autoExcludeTools = lib.optionals config.programs.git.enable [ "git" ];
  effectiveExcludeTools = lib.unique (cfg.excludeTools ++ autoExcludeTools);
  toolOverrides = {
    toolNamesOverride = cfg.toolNames;
    excludeToolNames = effectiveExcludeTools;
  };
  toolOverridesEnabled = cfg.toolNames != null || effectiveExcludeTools != [ ];
  toolSets = import ../../../tools/extended.nix ({ inherit pkgs; } // toolOverrides);
  defaultPackage =
    if toolOverridesEnabled && cfg.package == pkgs.openclaw then
      (pkgs.openclawPackages.withTools toolOverrides).openclaw
    else
      cfg.package;
  appPackage = if cfg.appPackage != null then cfg.appPackage else defaultPackage;
  qmdPackage = pkgs.openclawPackages.qmd or null;
  generatedConfigOptions = import ../../../generated/openclaw-config-options.nix { lib = lib; };
  pluginCatalog = import ./plugin-catalog.nix;

  bundledPluginSources =
    let
      openclawToolsRev = "4c1cee3c7eaf68f9de0f756be1484534f5bb5f34";
      openclawToolsNarHash = "sha256-tXWkN1VnwFG8XlRqW/e7VwbKnUfyU9tB7YDm9QHJXTY=";
      openclawTools =
        tool:
        "github:openclaw/nix-openclaw-tools?dir=tools/${tool}&rev=${openclawToolsRev}&narHash=${openclawToolsNarHash}";
    in
    lib.mapAttrs (_name: plugin: plugin.source or (openclawTools plugin.tool)) pluginCatalog;

  bundledPlugins = lib.filter (p: p != null) (
    lib.mapAttrsToList (
      name: source:
      let
        pluginCfg = cfg.bundledPlugins.${name};
      in
      if (pluginCfg.enable or false) then
        {
          inherit source;
          config = pluginCfg.config or { };
        }
      else
        null
    ) bundledPluginSources
  );

  effectivePlugins = cfg.customPlugins ++ bundledPlugins;

  resolvePath = p: if lib.hasPrefix "~/" p then "${homeDir}/${lib.removePrefix "~/" p}" else p;

  toRelative = p: if lib.hasPrefix "${homeDir}/" p then lib.removePrefix "${homeDir}/" p else p;

in
{
  inherit
    cfg
    homeDir
    toolOverrides
    toolOverridesEnabled
    toolSets
    defaultPackage
    appPackage
    qmdPackage
    generatedConfigOptions
    bundledPluginSources
    bundledPlugins
    effectivePlugins
    resolvePath
    toRelative
    ;
}
