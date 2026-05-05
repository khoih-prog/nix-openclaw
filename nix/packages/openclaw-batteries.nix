{
  lib,
  buildEnv,
  openclaw-gateway,
  openclaw-app ? null,
  extendedTools ? [ ],
  version ? null,
}:

let
  appPaths = lib.optional (openclaw-app != null) openclaw-app;
  appLinks = lib.optional (openclaw-app != null) "/Applications";
  bundleVersion =
    if version != null && version != "" then version else lib.getVersion openclaw-gateway;
in
buildEnv {
  name = "openclaw-${bundleVersion}";
  paths = [ openclaw-gateway ] ++ appPaths ++ extendedTools;
  pathsToLink = [ "/bin" ] ++ appLinks;

  meta = with lib; {
    description = "OpenClaw batteries-included bundle (gateway + app + tools)";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin ++ platforms.linux;
  };
}
