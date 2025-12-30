{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  makeBinaryWrapper,
  writableTmpDirAsHomeHook,
  dart-sass,
  prisma-engines,
  openssl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ziit";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "0PandaDEV";
    repo = "Ziit";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DNaXX9YFksmbMBcVHhwfRZfxS0fHEnkLSMj9cWVE0QI=";
  };

  node_modules = stdenvNoCC.mkDerivation {
    pname = "ziit-node_modules";
    version = finalAttrs.version;

    src = finalAttrs.src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ ["GIT_PROXY_COMMAND" "SOCKS_SERVER"];

    nativeBuildInputs = [bun writableTmpDirAsHomeHook];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

      bun install --force --frozen-lockfile --ignore-scripts --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/node_modules
      cp -R ./node_modules $out

      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-M+wYAY7NwGayTPTUhAKqcbLr6J5uzN5IEQ4rO7hfO0U=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [bun makeBinaryWrapper openssl];

  env = {
    NUXT_TELEMETRY_DISABLED = "1";
    PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines}/lib/libquery_engine.node";
    PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines}/bin/schema-engine";
  };

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.node_modules}/. .
    chmod -R +w node_modules

    mkdir -p node_modules/sass-embedded/dist/lib/src/vendor/dart-sass
    ln -s ${dart-sass}/bin/dart-sass node_modules/sass-embedded/dist/lib/src/vendor/dart-sass/sass

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    bun run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/ziit
    cp -R .output/server/* $out/share/ziit/
    cp -R prisma $out/share/ziit/

    mkdir -p $out/bin
    makeWrapper ${bun}/bin/bun $out/bin/ziit \
      --add-flags "run $out/share/ziit/index.mjs" \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine"

    runHook postInstall
  '';

  meta = {
    description = "The Swiss army knife of code time tracking";
    homepage = "https://github.com/0PandaDEV/Ziit";
    changelog = "https://github.com/0PandaDEV/Ziit/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "ziit";
  };
})
