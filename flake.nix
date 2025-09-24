{
  description = "NixBlitz dev env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    wasm-bindgen-cli-flake.url = "git+https://forge.f44.fyi/f44/wasm-bindgen-cli-flake?ref=main";
    dioxus-cli-flake.url = "git+https://forge.f44.fyi/f44/dioxus-cli-flake?ref=main";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    wasm-bindgen-cli-flake,
    dioxus-cli-flake,
  }: let
    cli_name = "nixblitz-cli";
    install_engine_name = "nixblitz-install-engine";
    system_engine_name = "nixblitz-system-engine";
    webapp_name = "nixblitz-norupo";

    module = {
      nixosModules = {
        ${cli_name} = {...}: {
          imports = [./modules/nixblitz_cli.nix];
          nixpkgs.overlays = [self.overlays.default];
        };
        ${install_engine_name} = {...}: {
          imports = [./modules/nixblitz_install_engine.nix];
          nixpkgs.overlays = [self.overlays.default];
        };
        ${system_engine_name} = {...}: {
          imports = [./modules/nixblitz_system_engine.nix];
          nixpkgs.overlays = [self.overlays.default];
        };
        ${webapp_name} = {...}: {
          imports = [
            (import ./modules/nixblitz_norupo.nix {
              inherit wasm-bindgen-cli-flake;
              inherit dioxus-cli-flake;
            })
          ];
          nixpkgs.overlays = [self.overlays.default];
        };
        default = self.nixosModules.${cli_name};
      };
    };

    overlays.overlays = {
      default = final: prev: {
        ${cli_name} = self.packages.${prev.stdenv.hostPlatform.system}.${cli_name};
        ${webapp_name} = self.packages.${prev.stdenv.hostPlatform.system}.${webapp_name};
        ${install_engine_name} = self.packages.${prev.stdenv.hostPlatform.system}.${install_engine_name};
        ${system_engine_name} = self.packages.${prev.stdenv.hostPlatform.system}.${system_engine_name};
      };
    };

    systems = flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      mainPkg = self.packages.${system}.${cli_name};
      revArgs =
        pkgs.lib.optionalAttrs (self ? rev && self.rev != null)
        {inherit (self) rev;};
      shortRevArgs =
        pkgs.lib.optionalAttrs (self ? shortRev && self.shortRev != null)
        {inherit (self) shortRev;};
    in {
      packages = {
        ${cli_name} =
          pkgs.callPackage ./crates/nixblitz_cli/default.nix
          (revArgs // shortRevArgs);
        ${webapp_name} = pkgs.callPackage ./crates/nixblitz_norupo/default.nix {
          inherit wasm-bindgen-cli-flake;
          inherit dioxus-cli-flake;
        };
        default = self.packages.${system}.${cli_name};
      };

      apps = {
        default = self.apps.${system}.${cli_name};
        ${cli_name} = {
          type = "app";
          program = "${mainPkg}/bin/nixblitz";
        };

        ${install_engine_name} = {
          type = "app";
          program = "${mainPkg}/bin/nixblitz_installer_engine";
        };

        ${system_engine_name} = {
          type = "app";
          program = "${mainPkg}/bin/nixblitz_system_engine";
        };
      };

      devShell = with pkgs;
        mkShell {
          buildInputs =
            [
              alejandra # nix formatter
              cargo # rust package manager
              cargo-deny # Cargo plugin to generate list of all licenses for a crate
              rust-analyzer
              vscode-extensions.vadimcn.vscode-lldb.adapter # for rust debugging
              rustc # rust compiler
              rustfmt
              pre-commit # https://pre-commit.com
              rustPackages.clippy # rust linter
              python3 # to build the xcb Rust library
              nixd # for the flake files
              statix
              nodePackages.prettier # for the markdown files
              dbus # needed for an openssl package
              openssl
              just # the command runner
              nushell # alternative to Bash
              typos # code spell checker
              statix
              fd
              lld
              nodejs
              tailwindcss_4
              watchman
              websocat
              binaryen
            ]
            ++ [
              wasm-bindgen-cli-flake.packages.${system}.wasm-bindgen-cli
              dioxus-cli-flake.packages.${system}.dioxus-cli
            ];
          nativeBuildInputs = with pkgs; [
            pkg-config
          ];
          RUST_SRC_PATH = rustPlatform.rustLibSrc;
        };
    });
  in
    overlays // module // systems;
}
