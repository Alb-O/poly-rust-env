# Rust Base Devenv (Nightly)

Reusable Rust nightly base environment for polyrepo setups using `devenv` v2.

This base is intended for practical backend/CLI Rust repos that need:
- consistent nightly toolchain + components
- consistent lint/test/format scripts
- consistent cross-target checks

## Includes

- Nightly toolchain from `rust-toolchain.toml`
- Components: `cargo`, `clippy`, `rustfmt`, `rust-analyzer`, `rust-src`, `llvm-tools-preview`
- Targets: `wasm32-unknown-unknown`, `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-gnu`
- Scripts: `fmt`, `fmt-check`, `lint`, `check`, `run-tests`, `check-targets`, `ci`

## Use from another repo

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  rust-overlay:
    url: github:oxalica/rust-overlay
    inputs:
      nixpkgs:
        follows: nixpkgs
  rust-base:
    url: github:Alb-O/rust-base-devenv-polyrepo
    flake: false
imports:
  - rust-base
```

Then run:

```bash
devenv test
```

Example app using this base:
- `Alb-O/rust-app` (`order-quote-cli`)
