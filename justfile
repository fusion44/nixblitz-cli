set shell := ["nu", "-c"]
rust_src := "./crates"
work_dir := "/tmp/something1"

set positional-arguments

# Lists available commands
default:
	just --list

# clean the workspace
clean:
  alejandra	.
  cd {{rust_src}}; cargo clean

# format all Nix files
format:
  alejandra	.
  cd {{rust_src}}; cargo fmt
  dx fmt

update-default-nix:
  #!/usr/bin/env nu
  nu ./scripts/update-default-nix.nu

  gum confirm "Commit changes?"
  git add crates/nixblitz_cli/default.nix crates/nixblitz_norupo/default.nix
  git commit -m "chore: update hashes"
  git push f44 main

update-flake-locks mode="nixblitz":
  #!/usr/bin/env nu
  fd flake.lock | lines | path dirname | each { |d|
    cd $d
    print $"Updating flakes in ($d)"
    let cmd = if ("{{mode}}" == "full") {
      nix flake update
    } else if ("{{mode}}" == "nixblitz") {
      nix flake update nixblitz
    } else {
      print "Unknown mode '{{mode}}'. Valid modes are 'full' and 'nixblitz'."
    }
  }

# inside the test vm: sync from shared folder to dev
sync-src-temp:
  rsync -av --exclude='target/' --exclude='.git' --exclude='result' /mnt/shared/ /home/nixos/dev

# Run lints and checks; Pass -f to apply auto fix where possible
lint fix="":
  #!/usr/bin/env nu
  if ("{{fix}}" == "") {
    typos
    cd {{rust_src}}
    cargo clippy --workspace -- --no-deps
    cargo fmt --all -- --check
  } else if ("{{fix}}" == "-f") {
    typos -w
    cd {{rust_src}}
    cargo clippy --fix --allow-dirty --allow-staged --workspace -- --no-deps
    cargo fmt --all
  } else {
    print "Unknown argument '{{fix}}'. Pass '-f' to auto fix or nothing to dry run."
  }

# runs all tests; Pass --trace (-t) to enable Rust tracing
test trace="":
  #!/usr/bin/env nu
  if ("{{trace}}" == "-t" or "{{trace}}" == "--trace") {
    cd {{rust_src}}
    $env.RUST_BACKTRACE = 1
    cargo test
  } else if ("{{trace}}" == "") {
    cd {{rust_src}}
    cargo test
  } else {
    print "Unknown argument '{{trace}}'. Pass '-t' to enable Rust tracing or nothing to run without it."
  }

# run the CLI with debug log enabled, any args are passed to the CLI unaltered
run-cli *args='':
  cd {{rust_src}}; $env.RUST_BACKTRACE = 1; $env.NIXBLITZ_LOG = "trace"; cargo run -p nixblitz_cli -- {{args}}

# serve the installer engine
run-installer-engine:
  cd {{rust_src}}; $env.NIXBLITZ_WORK_DIR = '{{work_dir}}'; $env.RUST_BACKTRACE = 1; $env.NIXBLITZ_DEMO = 1; $env.RUST_LOG = "debug"; cargo run -p nixblitz_installer_engine

run-system-engine:
  cd {{rust_src}}; $env.NIXBLITZ_WORK_DIR = '{{work_dir}}'; $env.RUST_BACKTRACE = 1; $env.RUST_LOG = "debug"; cargo run -p nixblitz_system_engine

# serve the norupo Web UI
run-norupo:
  cd {{rust_src}}/nixblitz_norupo; $env.NIXBLITZ_WORK_DIR = '{{work_dir}}'; $env.RUST_BACKTRACE = 1; $env.RUST_LOG = "debug"; dx serve --web

# run the tailwind CSS dev server
run-tailwind:
  cd {{rust_src}}/nixblitz_norupo; tailwindcss -i ./input.css -o ./assets/tailwind.css --watch

# shorthand for rsync this source directory to a remote node.
rsync target:
  #!/usr/bin/env nu
  if not ('.remotes.json' | path exists) {
    print "Config file '.remotes.json' not found."
    print "Find an example template '.remotes.json.sample'"
    exit 1
  }

  let data = open .remotes.json
  if ($data | columns | "all" in $in ) {
    print "The keyword 'all' is reserved to rsync to all the remotes declared in the .remotes.json file"
    exit 1
  }

  if ("{{target}}" == "all") {
    $data | transpose key value | each { |remote|
      print $"Syncing ($remote.key)"
      let data2 = $remote.value
      let cmd = $data2.user + "@" + $data2.host + ":" + $data2.path
      rsync -rvz --exclude .git --exclude crates/target/ . $cmd
    }
    exit 0
  } else {
    print $"Syncing {{target}}"
    let $data = $data | get {{target}}
    let cmd = $data.user + "@" + $data.host + ":" + $data.path
    rsync -rvz -e $'ssh -p ($data.port) -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no' --exclude nixblitz-disk.qcow2 --exclude .git --exclude crates/target/ . $cmd
  }

# Build all crates
nix-build-all:
  #!/usr/bin/env bash
  nix build .#nixblitz-cli
  nix build .#nixblitz-norupo
