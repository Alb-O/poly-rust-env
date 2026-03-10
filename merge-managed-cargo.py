#!/usr/bin/env python3
import json
import sys
import tomllib


DEPENDENCY_SECTION_NAMES = {
    "dependencies",
    "dev-dependencies",
    "build-dependencies",
}
PASSTHROUGH_SOURCE_KEYS = {"path", "git"}


def load_toml(path):
    with open(path, "rb") as handle:
        return tomllib.load(handle)


def fail(message):
    raise SystemExit(message)


def normalize_catalog_entry(crate_name, raw_entry):
    if isinstance(raw_entry, str):
        return {"version": raw_entry}

    if not isinstance(raw_entry, dict):
        fail(f"catalog entry for {crate_name!r} must be a string or table")

    normalized = dict(raw_entry)
    version = normalized.get("version")
    if not isinstance(version, str) or not version:
        fail(f"catalog entry for {crate_name!r} must define a non-empty version")

    return normalized


def normalize_dependency_spec(crate_name, raw_spec):
    if isinstance(raw_spec, bool):
        if raw_spec:
            return {}
        fail(f"dependency {crate_name!r} cannot be false")

    if isinstance(raw_spec, dict):
        return dict(raw_spec)

    fail(
        f"dependency {crate_name!r} must be a table or true in Cargo.dvnv.toml; "
        "string shorthand is not supported because versions come from the shared catalog"
    )


def merge_features(catalog_features, spec_features):
    merged = []

    for feature in list(catalog_features) + list(spec_features):
        if not isinstance(feature, str) or not feature:
            fail("dependency features must be non-empty strings")
        if feature not in merged:
            merged.append(feature)

    return merged


def merge_dependency(crate_name, raw_spec, catalog):
    spec = normalize_dependency_spec(crate_name, raw_spec)

    if "version" in spec and not any(key in spec for key in PASSTHROUGH_SOURCE_KEYS):
        fail(
            f"dependency {crate_name!r} must not declare version in Cargo.dvnv.toml; "
            "move the version into the shared catalog"
        )

    if any(key in spec for key in PASSTHROUGH_SOURCE_KEYS):
        return spec

    if crate_name not in catalog:
        fail(f"dependency {crate_name!r} is missing from the shared catalog")

    merged = dict(catalog[crate_name])
    merged.update(spec)

    if "features" in catalog[crate_name] or "features" in spec:
        merged["features"] = merge_features(
            catalog[crate_name].get("features", []),
            spec.get("features", []),
        )

    return merged


def visit(node, catalog):
    if isinstance(node, dict):
        result = {}
        for key, value in node.items():
            if key in DEPENDENCY_SECTION_NAMES:
                if not isinstance(value, dict):
                    fail(f"{key!r} must be a table")

                result[key] = {
                    crate_name: merge_dependency(crate_name, raw_spec, catalog)
                    for crate_name, raw_spec in value.items()
                }
            else:
                result[key] = visit(value, catalog)
        return result

    if isinstance(node, list):
        return [visit(item, catalog) for item in node]

    return node


def load_catalog(path):
    parsed = load_toml(path)

    if not isinstance(parsed, dict):
        fail("catalog TOML must be a top-level table")

    crates = parsed.get("crates", {})
    if not isinstance(crates, dict):
        fail("catalog TOML must define a [crates] table")

    return {
        crate_name: normalize_catalog_entry(crate_name, raw_entry)
        for crate_name, raw_entry in crates.items()
    }


def main():
    catalog_path, spec_path = sys.argv[1:3]
    catalog = load_catalog(catalog_path)
    spec = load_toml(spec_path)

    if not isinstance(spec, dict):
        fail("Cargo.dvnv.toml must be a top-level table")

    json.dump(visit(spec, catalog), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
