{
  lib,
  stdenv,
  fetchFromGitHub,
  bundler,
  ruby_3_4,
  bundlerEnv,
  makeWrapper,
  dataDir ? "/var/lib/sure",
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sure";
  version = "0.6.5-alpha.8";

  src = fetchFromGitHub {
    owner = "we-promise";
    repo = "sure";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1BkeNisDSUBK+ocqKgYKwUY+RaNObnRGASYK26nFUcM=";
  };

  bundler = bundler.override {ruby = ruby_3_4;};

  rubyEnv = bundlerEnv {
    name = "sure-gems";
    ruby = ruby_3_4;
    inherit (finalAttrs) bundler;
    gemdir = ./.;
  };

  buildInputs = [finalAttrs.rubyEnv];
  nativeBuildInputs = [makeWrapper];

  env.RAILS_ENV = "production";

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)

    bundle exec bootsnap precompile --gemfile app/ lib/
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out/

    runHook postInstall
  '';

  postInstall = ''
    chmod -R u+w $out

    ln -s ${dataDir}/.env $out/.env

    mkdir -p $out/bin

    makeWrapper ${finalAttrs.rubyEnv}/bin/bundle $out/bin/sure \
      --set RAILS_ENV production \
      --chdir $out \
      --add-flags "exec rails server"

    makeWrapper ${finalAttrs.rubyEnv}/bin/bundle $out/bin/sure-rails \
      --set RAILS_ENV production \
      --chdir $out \
      --add-flags "exec rails"

    makeWrapper ${finalAttrs.rubyEnv}/bin/bundle $out/bin/sure-worker \
      --set RAILS_ENV production \
      --chdir $out \
      --add-flags "exec sidekiq"
  '';

  meta = {
    description = "The personal finance app for everyone";
    homepage = "https://github.com/we-promise/sure";
    changelog = "https://github.com/we-promise/sure/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "sure";
    platforms = lib.platforms.unix;
  };
})
