{
  pkgs,
  rustPlatform,
  basePath ? "",
  wasm-bindgen-cli-flake,
  dioxus-cli-flake,
}: let
  jjHelpers = import ../../scripts/jj_helpers.nix {inherit (pkgs) lib;};
  src = ../../.;
  commitSha = jjHelpers.commitIdFromRepo {repoRoot = src;};
  manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
  shortSha = builtins.substring 0 7 commitSha;

  crateSource = src + "/crates";
  vergenGitDescribe = "${shortSha}-nix";
in
  rustPlatform.buildRustPackage {
    pname = "nixblitz-norupo";
    inherit (manifest) version;
    src = crateSource;
    cargoLock.lockFile = crateSource + "/Cargo.lock";

    VERGEN_GIT_SHA = commitSha;
    VERGEN_GIT_DESCRIBE = vergenGitDescribe;

    nativeBuildInputs = with pkgs;
      [
        rustPlatform.cargoSetupHook
        pkg-config
        cargo
        rustc
        lld
        binaryen
        tailwindcss_4
      ]
      ++ [
        wasm-bindgen-cli-flake.packages.${system}.wasm-bindgen-cli
        dioxus-cli-flake.packages.${system}.dioxus-cli
      ];

    buildInputs = [pkgs.openssl];

    preBuild = ''
      local templatePath="nixblitz_norupo/Dioxus.toml.templ"
      local configTargetPath="nixblitz_norupo/Dioxus.toml"
      rm -f "$configTargetPath"

      if [ ! -f "$templatePath" ]; then
        echo "Error: Dioxus.toml.templ not found at $templatePath"
        exit 1
      fi

      cp "$templatePath" "$configTargetPath"

      echo "Working with the given base_path = \"${basePath}\""

      local basePathLineToInject=""
      if [ -n "${basePath}" ]; then
        # string is not empty
        basePathLineToInject="base_path = \"${basePath}\""
      fi

      echo "Updating $configTargetPath: replacing '%%DIOXUS_BASE_PATH_LINE%%' with '$basePathLineToInject'"
      # substituteInPlace "$configTargetPath" \
      #   --replace "%%DIOXUS_BASE_PATH_LINE%%" "$basePathLineToInject"
      substituteInPlace "$configTargetPath" \
        --replace "%%DIOXUS_BASE_PATH_LINE%%" ""

      echo "--- Patched $configTargetPath ---"
      cat "$configTargetPath"
      echo "---------------------------------"
    '';

    buildPhase = ''
      runHook preBuild

      cd nixblitz_norupo
      echo "Current directory for build: $(pwd)"

      echo "Running 'dx bundle --platform web'"
      dx bundle --web --release

      cd ..

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      local installDir=$out/bin
      mkdir -p $installDir
      local assetsSourceDir="target/dx/nixblitz_norupo/release/web"

      if [ ! -d "$assetsSourceDir" ]; then
        echo "Error: Built Dioxus assets not found at $assetsSourceDir!"
        # echo "Listing contents of nixblitz_norupo/target/dx if it exists:"
        # ls -R target/dx 2>/dev/null || echo "nixblitz_norupo/target/dx does not exist or is empty"
        exit 1
      fi

      echo "Copying server binary and assets from $assetsSourceDir to $installDir"
      cp -R "$assetsSourceDir"/* $installDir

      runHook postInstall
    '';

    meta = {
      description = manifest.description or "A web UI for the NixBlitz project.";
      homepage = manifest.homepage or "https://github.com/fusion44/nixblitz";
      license = pkgs.lib.licenses.mit;
      maintainers = ["fusion44"];
      mainProgram = "nixblitz_norupo";
    };
  }
