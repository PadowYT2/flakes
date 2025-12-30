{
  lib,
  stdenv,
  applyPatches,
  fetchFromGitHub,
  ruby_3_4,
  bundlerEnv,
  tailwindcss_4,
  makeWrapper,
  dataDir ? "/var/lib/sure",
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sure";
  version = "0.6.6-alpha.8";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "we-promise";
      repo = "sure";
      tag = "v${finalAttrs.version}";
      hash = "sha256-+v3Fyc2zfWx4VpBNRas8GYk8h9VwSgpaa5E/rnyJ07E=";
    };

    patches = [
      ./0001-build-ffi-gem.diff
      ./0002-openssl-hotfix.diff
      ./0003-add-missing-nokogiri.diff
    ];

    postPatch = ''
      substituteInPlace ./Gemfile \
        --replace-fail 'ruby file: ".ruby-version"' 'ruby ">= 3.4.0"'
    '';
  };

  sureGems = bundlerEnv {
    name = "${finalAttrs.pname}-gems-${finalAttrs.version}";
    inherit (finalAttrs) version;
    ruby = ruby_3_4;
    gemset = "${./.}/gemset.nix";
    gemdir = finalAttrs.src;
  };

  RAILS_ENV = "production";
  TAILWINDCSS_INSTALL_DIR = "${tailwindcss_4}/bin";

  nativeBuildInputs = [makeWrapper finalAttrs.sureGems finalAttrs.sureGems.wrappedRuby];
  propagatedBuildInputs = [finalAttrs.sureGems.wrappedRuby];
  buildInputs = [finalAttrs.sureGems];

  buildPhase = ''
    runHook preBuild

    patchShebangs bin/
    for b in $(ls $sureGems/bin/ 2>/dev/null || true); do
      if [ ! -f bin/$b ]; then
        ln -s $sureGems/bin/$b bin/$b
      fi
    done

    export HOME=$(mktemp -d)
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

    rm -rf storage log tmp
    ln -s ${dataDir}/.env .env
    ln -s ${dataDir}/storage storage
    ln -s ${dataDir}/log log
    ln -s ${dataDir}/tmp tmp

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out/

    mkdir -p $out/bin

    makeWrapper ${finalAttrs.sureGems}/bin/bundle $out/bin/sure \
      --set RAILS_ENV production \
      --chdir $out \
      --add-flags "exec rails server"

    makeWrapper ${finalAttrs.sureGems}/bin/bundle $out/bin/sure-rails \
      --set RAILS_ENV production \
      --chdir $out \
      --add-flags "exec rails"

    makeWrapper ${finalAttrs.sureGems}/bin/bundle $out/bin/sure-worker \
      --set RAILS_ENV production \
      --chdir $out \
      --add-flags "exec sidekiq"

    runHook postInstall
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
