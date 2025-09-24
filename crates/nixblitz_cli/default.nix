# default.nix
{
  pkgs ? import <nixpkgs> {},
  rev ? null,
  shortRev ? null,
}: let
  jjHelpers = import ../../scripts/jj_helpers.nix {inherit (pkgs) lib;};
  src = ../../.;

  commitSha =
    if rev != null
    then rev
    else jjHelpers.commitIdFromRepo {repoRoot = src;};

  shortSha =
    if shortRev != null
    then shortRev
    else builtins.substring 0 7 commitSha;

  manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
  crateSource = src + "/crates";
  vergenGitDescribe = "${shortSha}-nix";
in
  pkgs.rustPlatform.buildRustPackage {
    pname = "nixblitz";
    inherit (manifest) version;
    src = crateSource;
    cargoLock.lockFile = crateSource + "/Cargo.lock";

    VERGEN_GIT_SHA = commitSha;
    VERGEN_GIT_DESCRIBE = vergenGitDescribe;

    buildPhase = ''
      runHook preBuild

      echo "Building the Installer Engine"
      cargo build --release --workspace --exclude nixblitz_norupo

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cargo install --root $out --path nixblitz_cli
      cargo install --root $out --path nixblitz_installer_engine
      cargo install --root $out --path nixblitz_system_engine

      runHook postInstall
    '';

    meta = {
      description = manifest.description or "Management CLI for the nixblitz project";
      homepage = manifest.homepage or "https://github.com/fusion44/nixblitz";
      license = pkgs.lib.licenses.mit;
      maintainers = ["fusion44"];
      mainProgram = "nixblitz";
    };
  }
