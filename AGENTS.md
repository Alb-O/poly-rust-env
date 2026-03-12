# Rust (nightly) style

- Global Rust build artifacts (CARGO_BUILD_BUILD_DIR): be patient with cargo lock, other projects inflight.
- No trivial tests. Avoid happy-path, instead test against the cruel outside world.
- Simplify & avoid over-handling. Lean on implicit/concise behavior as the go-to.
- Prefer functional style.
- Use where clause:

```rs
impl<T> Model for MyModel<T>
where
    T: /*...*/
```

## Managed Cargo deps

- Root Cargo.toml is nix-generated to sync dep versions across repos
  - To add deps to repo, edit Cargo.poly.toml (without dep ver number)
  - Regen Cargo.toml (devenv shell); if fails on dep not in Cargo.catalog.toml, add it
    - pin latest ver from cargo info
