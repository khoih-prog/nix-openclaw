{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_22,
  openclawPackage,
}:

lock:

let
  runtimeEntries =
    (lock.runtimeExtensions or [ ])
    ++ lib.optional ((lock.runtimeSetupEntry or null) != null) lock.runtimeSetupEntry;
  runtimeEntriesFile = builtins.toFile "openclaw-runtime-plugin-${lock.id}-runtime-entries" (
    (lib.concatStringsSep "\n" runtimeEntries) + "\n"
  );
  shrinkwrapPathsFile = builtins.toFile "openclaw-runtime-plugin-${lock.id}-shrinkwrap-paths" (
    (lib.concatStringsSep "\n" (lock.bundledPackageRoots or [ ])) + "\n"
  );
  hasRuntimeDependencies =
    (lock.dependencies or { }) != { } || (lock.optionalDependencies or { }) != { };
  safeName = lib.replaceStrings [ "@" "/" ":" ] [ "" "-" "-" ] lock.id;

  drv = stdenvNoCC.mkDerivation {
    pname = "openclaw-runtime-plugin-${safeName}";
    version = lock.version;

    src = fetchurl {
      url = lock.tarballUrl;
      hash = lock.nixHash;
    };

    sourceRoot = "package";

    nativeBuildInputs = [ nodejs_22 ];

    dontConfigure = true;
    dontBuild = true;

    env = {
      OPENCLAW_GATEWAY_PACKAGE = "${openclawPackage}";
      OPENCLAW_RUNTIME_PLUGIN_ID = lock.id;
      OPENCLAW_RUNTIME_PLUGIN_PACKAGE_NAME = lock.packageName;
      OPENCLAW_RUNTIME_PLUGIN_VERSION = lock.version;
      OPENCLAW_RUNTIME_PLUGIN_COMPAT = lock.openclawCompat;
      OPENCLAW_RUNTIME_PLUGIN_PEER_OPENCLAW = lock.peerOpenClaw;
      OPENCLAW_RUNTIME_PLUGIN_RUNTIME_ENTRIES_FILE = runtimeEntriesFile;
      OPENCLAW_RUNTIME_PLUGIN_SHRINKWRAP_PATHS_FILE = shrinkwrapPathsFile;
      OPENCLAW_RUNTIME_PLUGIN_HAS_RUNTIME_DEPENDENCIES = if hasRuntimeDependencies then "1" else "0";
    };

    installPhase = "${nodejs_22}/bin/node ${../scripts/openclaw-runtime-plugin-install.mjs}";

    passthru.openclawRuntimePlugin = {
      inherit (lock)
        id
        packageName
        version
        npmIntegrity
        ;
      source = "npm";
      loadPath = drv;
    };

    meta = with lib; {
      description = "Nix-packaged OpenClaw runtime plugin ${lock.id}";
      homepage = "https://github.com/openclaw/openclaw";
      license = licenses.mit;
      platforms = platforms.darwin ++ platforms.linux;
    };
  };
in
drv
