#!/usr/bin/env python3
"""Create and conservatively restore Claudex installation snapshots."""

from __future__ import annotations

import argparse
from collections.abc import Callable
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import sys


def fail(message: str) -> None:
    raise SystemExit(f"Claudex install state: {message}")


def ensure_private_directory(path: Path) -> None:
    if path.exists() and (path.is_symlink() or not path.is_dir()):
        fail(f"refusing unsafe state directory: {path}")
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(0o700)


def write_json(path: Path, value: object) -> None:
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
    temporary.chmod(0o600)
    temporary.replace(path)


def read_json(path: Path, default: object | None = None) -> object:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        if default is not None:
            return default
        fail(f"missing manifest: {path}")
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read manifest {path}: {exc}")


def entry_kind(path: Path) -> str:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return "missing"
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISDIR(mode):
        return "directory"
    return "unsupported"


def fingerprint(path: Path) -> str | None:
    kind = entry_kind(path)
    if kind == "missing":
        return None
    if kind == "unsupported":
        fail(f"unsupported managed path type: {path}")

    digest = hashlib.sha256()

    def add_entry(item: Path, relative: str) -> None:
        metadata = item.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            digest.update(f"L\0{relative}\0{stat.S_IMODE(metadata.st_mode):o}\0".encode())
            digest.update(os.readlink(item).encode())
        elif stat.S_ISREG(metadata.st_mode):
            digest.update(f"F\0{relative}\0{stat.S_IMODE(metadata.st_mode):o}\0".encode())
            with item.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        elif stat.S_ISDIR(metadata.st_mode):
            digest.update(f"D\0{relative}\0{stat.S_IMODE(metadata.st_mode):o}\0".encode())
            for child in sorted(item.iterdir(), key=lambda value: value.name):
                child_relative = f"{relative}/{child.name}" if relative else child.name
                add_entry(child, child_relative)
        else:
            fail(f"unsupported managed path type: {item}")

    add_entry(path, "")
    return digest.hexdigest()


def remove_entry(path: Path) -> None:
    kind = entry_kind(path)
    if kind == "missing":
        return
    if kind == "directory":
        shutil.rmtree(path)
    else:
        path.unlink()


def copy_entry(source: Path, destination: Path) -> None:
    kind = entry_kind(source)
    if kind == "missing":
        return
    if kind == "unsupported":
        fail(f"unsupported managed path type: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if kind == "directory":
        shutil.copytree(source, destination, symlinks=True)
    elif kind == "symlink":
        destination.symlink_to(os.readlink(source))
    else:
        shutil.copy2(source, destination, follow_symlinks=False)


def restore_entry(target: Path, existed: bool, backup: Path | None) -> None:
    remove_entry(target)
    if existed:
        if backup is None or entry_kind(backup) == "missing":
            fail(f"backup is missing for {target}")
        copy_entry(backup, target)


def normalize_targets(lines: list[str]) -> list[Path]:
    targets: list[Path] = []
    seen: set[str] = set()
    for raw in lines:
        value = raw.rstrip("\n")
        if not value:
            continue
        path = Path(value)
        if not path.is_absolute():
            fail(f"managed target must be absolute: {value}")
        normalized = str(path)
        if normalized not in seen:
            targets.append(path)
            seen.add(normalized)
    if not targets:
        fail("no managed targets were provided")
    return targets


def begin(state_root: Path) -> None:
    targets = normalize_targets(sys.stdin.readlines())
    for target in targets:
        kind = entry_kind(target)
        if kind == "symlink":
            fail(f"refusing symlinked managed target before mutation: {target}")
        if kind == "unsupported":
            fail(f"unsupported managed path type: {target}")

    ensure_private_directory(state_root)
    backups = state_root / "runs"
    ensure_private_directory(backups)
    ownership_path = state_root / "ownership.json"
    ownership = read_json(ownership_path, {"format": 1, "targets": {}})
    if not isinstance(ownership, dict) or ownership.get("format") != 1 or not isinstance(ownership.get("targets"), dict):
        fail(f"invalid ownership manifest: {ownership_path}")

    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run_id = f"{timestamp}-{os.getpid()}"
    run_dir = backups / run_id
    pre_dir = run_dir / "pre"
    ensure_private_directory(run_dir)
    ensure_private_directory(pre_dir)

    run_targets: list[dict[str, object]] = []
    owned_targets: dict[str, dict[str, object]] = ownership["targets"]
    for index, target in enumerate(targets):
        kind = entry_kind(target)
        existed = kind != "missing"
        pre_hash = fingerprint(target)
        backup_name = f"{index:04d}"
        if existed:
            copy_entry(target, pre_dir / backup_name)
        record = {
            "path": str(target),
            "existed": existed,
            "pre_hash": pre_hash,
            "backup": backup_name if existed else None,
            "post_hash": None,
        }
        run_targets.append(record)
        if str(target) not in owned_targets:
            owned_targets[str(target)] = {
                "original_existed": existed,
                "original_hash": pre_hash,
                "original_run": run_id,
                "original_backup": backup_name if existed else None,
                "installed_hash": None,
                "last_run": None,
            }

    run_manifest = {
        "format": 1,
        "run_id": run_id,
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "finalized": False,
        "targets": run_targets,
    }
    write_json(run_dir / "manifest.json", run_manifest)
    write_json(ownership_path, ownership)
    print(run_id)


def finalize(state_root: Path, run_id: str) -> None:
    run_path = state_root / "runs" / run_id / "manifest.json"
    ownership_path = state_root / "ownership.json"
    run = read_json(run_path)
    ownership = read_json(ownership_path)
    if not isinstance(run, dict) or run.get("run_id") != run_id or not isinstance(run.get("targets"), list):
        fail(f"invalid run manifest: {run_path}")
    if not isinstance(ownership, dict) or not isinstance(ownership.get("targets"), dict):
        fail(f"invalid ownership manifest: {ownership_path}")
    for record in run["targets"]:
        target = Path(record["path"])
        post_hash = fingerprint(target)
        record["post_hash"] = post_hash
        owned = ownership["targets"].get(str(target))
        if not isinstance(owned, dict):
            fail(f"ownership entry disappeared for {target}")
        owned["installed_hash"] = post_hash
        owned["last_run"] = run_id
    run["finalized"] = True
    run["finalized_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
    write_json(run_path, run)
    write_json(ownership_path, ownership)


def list_backups(state_root: Path) -> None:
    runs = state_root / "runs"
    if not runs.is_dir():
        return
    for run_dir in sorted(runs.iterdir()):
        manifest = read_json(run_dir / "manifest.json")
        status = "finalized" if manifest.get("finalized") else "incomplete"
        print(f"{manifest.get('run_id', run_dir.name)}\t{status}\t{manifest.get('created_at', '')}")


def validate_restore(records: list[dict[str, object]], expected_key: str) -> list[str]:
    conflicts: list[str] = []
    for record in records:
        target = Path(record["path"])
        expected = record.get(expected_key)
        current = fingerprint(target)
        if current != expected:
            conflicts.append(f"{target} (current state differs from recorded installed state)")
    return conflicts


def validate_backups(
    records: list[dict[str, object]],
    backup_for: Callable[[dict[str, object]], Path | None],
    existed_key: str,
    expected_hash_key: str,
) -> None:
    errors: list[str] = []
    for record in records:
        if not record.get(existed_key):
            continue
        backup = backup_for(record)
        if backup is None or fingerprint(backup) != record.get(expected_hash_key):
            errors.append(str(record["path"]))
    if errors:
        fail("backup integrity check failed for:\n  " + "\n  ".join(errors))


def restore_backup(state_root: Path, run_id: str) -> None:
    run_dir = state_root / "runs" / run_id
    run_path = run_dir / "manifest.json"
    run = read_json(run_path)
    if not isinstance(run, dict) or not run.get("finalized") or not isinstance(run.get("targets"), list):
        fail(f"backup {run_id} is incomplete or invalid")
    records = run["targets"]
    conflicts = validate_restore(records, "post_hash")
    if conflicts:
        fail("rollback refused; resolve these changed paths first:\n  " + "\n  ".join(conflicts))
    validate_backups(
        records,
        lambda record: run_dir / "pre" / str(record["backup"]) if record.get("backup") else None,
        "existed",
        "pre_hash",
    )
    for record in records:
        backup = run_dir / "pre" / record["backup"] if record.get("backup") else None
        restore_entry(Path(record["path"]), bool(record["existed"]), backup)

    ownership_path = state_root / "ownership.json"
    ownership = read_json(ownership_path)
    for record in records:
        owned = ownership.get("targets", {}).get(record["path"])
        if isinstance(owned, dict):
            owned["installed_hash"] = record.get("pre_hash")
            owned["last_run"] = f"rollback:{run_id}"
    write_json(ownership_path, ownership)
    print(f"Restored Claudex backup {run_id}.")


def restore_original(state_root: Path) -> None:
    ownership_path = state_root / "ownership.json"
    ownership = read_json(ownership_path)
    targets = ownership.get("targets") if isinstance(ownership, dict) else None
    if not isinstance(targets, dict) or not targets:
        fail("no Claudex ownership manifest was found")
    records = [{"path": path, **record} for path, record in targets.items()]
    conflicts = validate_restore(records, "installed_hash")
    if conflicts:
        fail("uninstall refused; resolve these changed paths first:\n  " + "\n  ".join(conflicts))
    validate_backups(
        records,
        lambda record: (
            state_root / "runs" / str(record["original_run"]) / "pre" / str(record["original_backup"])
            if record.get("original_backup")
            else None
        ),
        "original_existed",
        "original_hash",
    )
    for record in records:
        original_run = str(record["original_run"])
        backup_name = record.get("original_backup")
        backup = state_root / "runs" / original_run / "pre" / str(backup_name) if backup_name else None
        restore_entry(Path(record["path"]), bool(record["original_existed"]), backup)
        record["installed_hash"] = record.get("original_hash")
        record["last_run"] = "uninstalled"
        targets[record["path"]]["installed_hash"] = record.get("original_hash")
        targets[record["path"]]["last_run"] = "uninstalled"
    write_json(ownership_path, ownership)
    print("Restored the original pre-Claudex managed files.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-root", required=True, type=Path)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("begin")
    finalize_parser = subparsers.add_parser("finalize")
    finalize_parser.add_argument("run_id")
    subparsers.add_parser("list")
    restore_parser = subparsers.add_parser("restore-backup")
    restore_parser.add_argument("run_id")
    subparsers.add_parser("restore-original")
    args = parser.parse_args()

    if args.command == "begin":
        begin(args.state_root)
    elif args.command == "finalize":
        finalize(args.state_root, args.run_id)
    elif args.command == "list":
        list_backups(args.state_root)
    elif args.command == "restore-backup":
        restore_backup(args.state_root, args.run_id)
    elif args.command == "restore-original":
        restore_original(args.state_root)


if __name__ == "__main__":
    main()
