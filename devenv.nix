{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config."rust-env";
  managedCargoCfg = cfg.managedCargo;
  xdgCacheHome =
    let
      fromXdg = builtins.getEnv "XDG_CACHE_HOME";
      fromHome = builtins.getEnv "HOME";
    in
    if fromXdg != "" then
      fromXdg
    else if fromHome != "" then
      "${fromHome}/.cache"
    else
      "/tmp";
  repoDir = baseNameOf config.git.root;
  cargoBuildDir =
    "${xdgCacheHome}/cargo/targets" + lib.optionalString cfg.separateCargoBuildDirByRepo "/${repoDir}";
  resolveFromRoot = path: if lib.hasPrefix "/" path then path else "${config.devenv.root}/${path}";
  # treefmt can only match files under the current repo root. Reduce the managed
  # spec path to a repo-relative include pattern when possible, and ignore it
  # entirely when the user points at something outside the repo.
  relativizeToRoot =
    path:
    let
      root = toString config.devenv.root;
      resolved = resolveFromRoot path;
      rootPrefix = "${root}/";
    in
    if resolved == root then
      "."
    else if lib.hasPrefix rootPrefix resolved then
      lib.removePrefix rootPrefix resolved
    else
      null;
  managedCargoSpecInclude =
    let
      relativePath = relativizeToRoot managedCargoCfg.specPath;
    in
    if relativePath == null || relativePath == "." || relativePath == "Cargo.toml" then
      null
    else
      relativePath;
  cargoSortIncludes = [
    "Cargo.toml"
    "**/Cargo.toml"
  ]
  ++ lib.optionals (managedCargoSpecInclude != null) [ managedCargoSpecInclude ];
  treefmtBin = lib.getExe config.treefmt.config.build.wrapper;
  prepareCargoSortWorkspace = ./prepare-cargo-sort-workspace.py;
  cargoSortWrapper = pkgs.writeShellScriptBin "cargo-sort-wrapper" ''
    set -euo pipefail

    opts=()
    files=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --*) opts+=("$1"); shift ;;
        *) files+=("$1"); shift ;;
      esac
    done

    for f in "''${files[@]}"; do
      dir="$(dirname "$f")"
      base="$(basename "$f")"

      if [[ "$base" == "Cargo.toml" ]]; then
        ${pkgs.lib.getExe pkgs.cargo-sort} "''${opts[@]}" "$dir"
        continue
      fi

      (
        set -euo pipefail

        # cargo-sort only knows how to operate on a file literally named
        # Cargo.toml. For managed spec files like Cargo.dvnv.toml, build a
        # short-lived scratch workspace with only the manifests cargo-sort needs:
        # the root spec plus any workspace member Cargo.toml files.
        temp_workspace="$(mktemp -d "$dir/cargo-sort-wrapper.XXXXXX")"

        cleanup_temp_workspace() {
          rm -rf "$temp_workspace"
        }

        trap cleanup_temp_workspace EXIT

        ${pkgs.lib.getExe pkgs.python3} ${prepareCargoSortWorkspace} "$f" "$temp_workspace"
        (
          cd "$temp_workspace"
          ${pkgs.lib.getExe pkgs.cargo-sort} "''${opts[@]}" .
        )
        cp "$temp_workspace/Cargo.toml" "$f"
        cleanup_temp_workspace
        trap - EXIT
      )
    done
  '';
in
{
  imports = [ ./managed-cargo.nix ];

  options."rust-env" = {
    separateCargoBuildDirByRepo = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Store Cargo build artifacts under a repo-specific subdirectory inside
        ${xdgCacheHome}/cargo/targets.
      '';
    };

  };

  config = lib.mkMerge [
    {
      env.CARGO_BUILD_BUILD_DIR = cargoBuildDir;

      languages.rust = {
        enable = true;
        toolchainFile = ./rust-toolchain.toml;
        lsp.enable = true;
      };

      treefmt = {
        enable = lib.mkDefault true;
        config = {
          programs.rustfmt.enable = lib.mkDefault true;
          settings.formatter.cargo-sort = {
            command = "${cargoSortWrapper}/bin/cargo-sort-wrapper";
            options = [ "--workspace" ];
            includes = cargoSortIncludes;
          };
        };
      };

      git-hooks = lib.mkIf config.treefmt.enable {
        hooks.treefmt.enable = lib.mkDefault true;
      };

      packages = [
        pkgs.just
        pkgs.openssl
        pkgs.pkg-config
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        pkgs.lld
        pkgs.mold
      ];

      scripts = {
        fmt.exec = treefmtBin;
        fmt-check.exec = "${treefmtBin} --fail-on-change";
        lint.exec = "cargo clippy --workspace --all-targets --all-features -- -D warnings";
        run-tests.exec = "cargo test --workspace --all-targets --all-features";
        check.exec = "cargo check --workspace --all-targets --all-features";
        check-targets.exec = ''
          set -euo pipefail
          cargo check --workspace --target wasm32-unknown-unknown
          cargo check --workspace --target x86_64-unknown-linux-musl
          cargo check --workspace --target aarch64-unknown-linux-gnu
        '';
        ci.exec = ''
          set -euo pipefail
          fmt-check
          lint
          check
          run-tests
          check-targets
        '';
      };

      outputs = lib.mkMerge [
        {
          rust-toolchain = config.languages.rust.toolchainPackage;
        }
      ];

      enterTest = ''
        set -euo pipefail

        rustc --version | grep -E "nightly|dev"
        cargo --version
        rustfmt --version
        clippy-driver --version

        fmt-check
        lint
        run-tests
        check-targets
      '';
    }
  ];
}
