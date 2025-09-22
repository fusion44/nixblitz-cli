{
  pkgs,
  rustPlatform,
  basePath ? "",
  wasm-bindgen-cli-flake,
  dioxus-cli-flake,
}: let
  manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
  commitSha = "18405ff94d41a6db163685b600d4ecacf1f12f3a";
  shortSha = builtins.substring 0 7 commitSha;

  # for local development
  # src = ./..;

  src = pkgs.fetchgit {
    url = "https://forge.f44.fyi/f44/nixblitz";
    rev = commitSha;
    sha256 = "sha256-v/OL7ksacyUVjey96AjKaprBIOyxXM5vqRbvogGkox0=";
  };

  # src = fetchFromGitHub {
  #   owner = "fusion44";
  #   repo = "nixblitz";
  #   rev = "1bc9027bdc32a8b7228c9dbcd707acf860163e67";
  #   sha256 = "sha256-ag6wM9C+lj/m6zeEp0W0inRWMgAm5dgbejsqKK9OXVE=";
  # };

  crateSource = src + "/crates";
  vergenGitSha = commitSha;
  vergenGitDescribe = "${shortSha}-nix";
  vergenGitDirty = "false";

  vergenSourceDateEpoch = "0";
in
  rustPlatform.buildRustPackage {
    pname = "nixblitz-norupo";
    inherit (manifest) version;
    src = crateSource;
    cargoLock.lockFile = crateSource + "/Cargo.lock";

    VERGEN_GIT_SHA = vergenGitSha;
    VERGEN_GIT_DESCRIBE = vergenGitDescribe;
    VERGEN_GIT_DIRTY = vergenGitDirty;
    SOURCE_DATE_EPOCH = vergenSourceDateEpoch;

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
      mainProgram = "server";
    };
  }
