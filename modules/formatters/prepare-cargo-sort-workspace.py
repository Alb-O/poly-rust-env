#!/usr/bin/env python3
import glob
import os
import pathlib
import shutil
import sys
import tomllib


def load_toml(path: pathlib.Path):
    with path.open("rb") as handle:
        return tomllib.load(handle)


def copy_member_manifest(repo_root: pathlib.Path, scratch_root: pathlib.Path, member_dir: pathlib.Path):
    source_manifest = member_dir / "Cargo.toml"
    if not source_manifest.is_file():
        return

    relative_dir = member_dir.relative_to(repo_root)
    target_dir = scratch_root / relative_dir
    target_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_manifest, target_dir / "Cargo.toml")


def iter_workspace_member_dirs(repo_root: pathlib.Path, workspace_cfg: dict):
    members = workspace_cfg.get("members", [])
    excludes = workspace_cfg.get("exclude", [])

    if not isinstance(members, list):
        return

    excluded = set()
    for pattern in excludes:
        if not isinstance(pattern, str):
            continue
        for match in glob.glob(str(repo_root / pattern), recursive=True):
            excluded.add(pathlib.Path(match).resolve())

    for pattern in members:
        if not isinstance(pattern, str):
            continue

        for match in glob.glob(str(repo_root / pattern), recursive=True):
            member_dir = pathlib.Path(match)
            if not member_dir.is_dir():
                continue
            if member_dir.resolve() in excluded:
                continue
            yield member_dir


def main():
    spec_path = pathlib.Path(sys.argv[1]).resolve()
    scratch_root = pathlib.Path(sys.argv[2]).resolve()
    repo_root = spec_path.parent

    shutil.copy2(spec_path, scratch_root / "Cargo.toml")

    spec = load_toml(spec_path)
    workspace_cfg = spec.get("workspace")
    if not isinstance(workspace_cfg, dict):
        return

    for member_dir in iter_workspace_member_dirs(repo_root, workspace_cfg):
        copy_member_manifest(repo_root, scratch_root, member_dir)


if __name__ == "__main__":
    main()
