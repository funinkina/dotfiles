#!/usr/bin/env python3
"""
helium-backup.py
Cross-platform backup & restore for the Helium browser (Chromium-based).
Supported operating systems: macOS, Linux, Windows

Usage:
  python3 helium-backup.py          # Interactive mode
  HELIUM_SRC=/path python3 helium-backup.py  # Override source path
"""

import os
import sys
import platform
import tarfile
import hashlib
import shutil
import subprocess
import datetime
from pathlib import Path
from typing import Dict, List, Optional

# ---------------------------------------------------------------------------
# Colors (ANSI – active on Windows only if VT100 is supported)
# ---------------------------------------------------------------------------


def _supports_color() -> bool:
    if platform.system() == "Windows":
        try:
            import ctypes

            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
            return True
        except Exception:
            return False
    return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()


_COLOR = _supports_color()


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


def log(msg: str) -> None:
    print(_c("1;34", "[helium-backup]") + f" {msg}")


def warn(msg: str) -> None:
    print(_c("1;33", "[warning]") + f" {msg}", file=sys.stderr)


def err(msg: str) -> None:
    print(_c("1;31", "[error]") + f" {msg}", file=sys.stderr)


def ok(msg: str) -> None:
    print(_c("1;32", "[ok]") + f" {msg}")


def sep() -> None:
    width = shutil.get_terminal_size((72, 20)).columns
    print(_c("90", "─" * min(width, 72)))


# ---------------------------------------------------------------------------
# OS detection & profile paths
# ---------------------------------------------------------------------------

OS_WINDOWS = "Windows"
OS_MACOS = "macOS"
OS_LINUX = "Linux"

CANDIDATE_PATHS: Dict[str, List[Path]] = {
    OS_MACOS: [
        Path.home() / "Library" / "Application Support" / "net.imput.helium",
        Path.home() / "Library" / "Application Support" / "Helium",
        Path.home() / "Library" / "Application Support" / "Helium Browser",
        Path.home() / "Library" / "Application Support" / "io.helium.Helium",
    ],
    OS_LINUX: [
        Path.home() / ".config" / "net.imput.helium",
        Path.home() / ".config" / "helium",
        Path.home() / ".config" / "Helium",
        Path.home() / ".config" / "Helium Browser",
        Path.home() / ".local" / "share" / "helium",
        Path.home() / ".local" / "share" / "Helium",
    ],
    OS_WINDOWS: [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Helium" / "User Data",
        Path(os.environ.get("LOCALAPPDATA", "")) / "net.imput.helium" / "User Data",
        Path(os.environ.get("APPDATA", "")) / "Helium",
        Path(os.environ.get("APPDATA", "")) / "net.imput.helium",
    ],
}


def detect_os() -> Optional[str]:
    system = platform.system()
    if system == "Darwin":
        return OS_MACOS
    if system == "Linux":
        return OS_LINUX
    if system == "Windows":
        return OS_WINDOWS
    return None


def select_os() -> str:
    detected = detect_os()
    if detected:
        log(f"Operating system auto-detected: {_c('1', detected)}")
        answer = input("  Is that correct? [Y/n] ").strip().lower()
        if answer in ("", "j", "y", "ja", "yes"):
            return detected

    print()
    print("Please select an operating system:")
    choices = [OS_MACOS, OS_LINUX, OS_WINDOWS]
    for i, name in enumerate(choices, 1):
        print(f"  [{i}] {name}")
    while True:
        raw = input("  Choice (1-3): ").strip()
        if raw in ("1", "2", "3"):
            return choices[int(raw) - 1]
        warn("Invalid input – please enter 1, 2, or 3.")


# ---------------------------------------------------------------------------
# Find the Helium profile directory
# ---------------------------------------------------------------------------


def find_helium_src(os_name: str) -> Optional[Path]:
    env_override = os.environ.get("HELIUM_SRC", "").strip()
    if env_override:
        p = Path(env_override)
        if p.is_dir():
            return p
        err(f"HELIUM_SRC set, but the directory does not exist: {p}")
        return None

    for candidate in CANDIDATE_PATHS.get(os_name, []):
        if candidate.is_dir():
            return candidate
    return None


# ---------------------------------------------------------------------------
# Is Helium running?
# ---------------------------------------------------------------------------


def helium_running() -> bool:
    try:
        if platform.system() == "Windows":
            result = subprocess.run(
                ["tasklist", "/FI", "IMAGENAME eq helium.exe"],
                capture_output=True,
                text=True,
            )
            return "helium.exe" in result.stdout.lower()
        else:
            result = subprocess.run(
                ["pgrep", "-i", "-f", "helium"], capture_output=True, text=True
            )
            # pgrep -f also matches this script's own command line
            pids = {int(p) for p in result.stdout.split()}
            pids -= {os.getpid(), os.getppid()}
            return bool(pids)
    except FileNotFoundError:
        return False


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def human_size(path: Path) -> str:
    if path.is_file():
        total = path.stat().st_size
    else:
        total = sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
    for unit in ("B", "KB", "MB", "GB"):
        if total < 1024:
            return f"{total:.1f} {unit}"
        total /= 1024
    return f"{total:.1f} TB"


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


EXCLUDE_DIRS = {
    "Cache",
    "Code Cache",
    "GPUCache",
    "ShaderCache",
    "GrShaderCache",
    "CacheStorage",
    "Crashpad",
    "component_crx_cache",
}


def _should_exclude(member_name: str) -> bool:
    parts = Path(member_name).parts
    # Singleton* are Chromium's instance-lock sockets/symlinks; restoring
    # stale ones can make Helium think another instance is running.
    return any(p in EXCLUDE_DIRS for p in parts) or parts[-1].startswith("Singleton")


def ask_confirm(prompt: str, default_yes: bool = False) -> bool:
    hint = "[Y/n]" if default_yes else "[y/N]"
    answer = input(f"{prompt} {hint} ").strip().lower()
    if default_yes:
        return answer not in ("n", "nein", "no")
    return answer in ("j", "y", "ja", "yes")


# ---------------------------------------------------------------------------
# Export (backup)
# ---------------------------------------------------------------------------


def do_export(src: Path, script_dir: Path) -> None:
    sep()
    log(f"Source: {src}  ({human_size(src)})")

    if helium_running():
        warn("Helium appears to be running right now.")
        warn("Open databases (cookies, history …) may be inconsistent.")
        if not ask_confirm("Export anyway?", default_yes=False):
            log("Aborted.")
            return

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    hostname = platform.node().split(".")[0].replace(" ", "-") or "host"
    archive_name = f"helium-backup_{hostname}_{timestamp}.tar.gz"
    archive_path = script_dir / archive_name
    tmp_path = archive_path.with_suffix(".partial")

    log(f"Writing archive: {archive_path}")

    with tarfile.open(tmp_path, "w:gz") as tar:
        for item in src.rglob("*"):
            rel = item.relative_to(src.parent)
            if _should_exclude(str(rel)):
                continue
            try:
                # recursive=False: rglob already visits every entry; letting
                # tar.add recurse duplicates files and bypasses the excludes
                tar.add(item, arcname=str(rel), recursive=False)
            except (PermissionError, OSError) as exc:
                warn(f"Skipped ({exc}): {item}")

    tmp_path.rename(archive_path)

    digest = sha256_of(archive_path)
    checksum_path = archive_path.with_suffix(".gz.sha256")
    checksum_path.write_text(f"{digest}  {archive_name}\n", encoding="utf-8")

    sep()
    ok(f"Archive created : {archive_path}")
    ok(f"Size            : {human_size(archive_path)}")
    ok(f"SHA-256         : {digest}")
    ok(f"Checksum        : {checksum_path}")


# ---------------------------------------------------------------------------
# Import (restore)
# ---------------------------------------------------------------------------


def verify_checksum(archive: Path) -> bool:
    checksum_file = archive.with_suffix(".gz.sha256")
    if not checksum_file.exists():
        warn("No checksum file found – verification skipped.")
        return True
    fields = checksum_file.read_text(encoding="utf-8").split()
    if not fields:
        warn("Checksum file is empty – verification skipped.")
        return True
    expected = fields[0]
    actual = sha256_of(archive)
    if expected == actual:
        ok("SHA-256 checksum matches.")
        return True
    err(f"SHA-256 MISMATCH!\n  Expected: {expected}\n  Found: {actual}")
    return False


def list_archives(script_dir: Path) -> list[Path]:
    return sorted(
        script_dir.glob("helium-backup_*.tar.gz"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )


def choose_archive(script_dir: Path) -> Optional[Path]:
    archives = list_archives(script_dir)
    if not archives:
        err(f"No backup archives found in {script_dir}.")
        return None

    print()
    print("Available backups:")
    for i, arc in enumerate(archives, 1):
        mtime = datetime.datetime.fromtimestamp(arc.stat().st_mtime).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        size = human_size(arc)
        print(f"  [{i}] {arc.name}  —  {mtime}  ({size})")

    if len(archives) == 1:
        if ask_confirm("\nUse this backup?", default_yes=True):
            return archives[0]
        return None

    while True:
        raw = input(f"  Choice (1-{len(archives)}): ").strip()
        if raw.isdigit() and 1 <= int(raw) <= len(archives):
            return archives[int(raw) - 1]
        warn("Invalid input.")


def do_import(os_name: str, script_dir: Path) -> None:
    sep()
    archive = choose_archive(script_dir)
    if archive is None:
        return

    if not verify_checksum(archive):
        if not ask_confirm("The archive may be corrupted. Import anyway?"):
            log("Aborted.")
            return

    # Determine destination path
    candidates = CANDIDATE_PATHS.get(os_name, [])
    dest_parent: Path | None = None

    # Prefer an existing path
    for c in candidates:
        if c.is_dir():
            dest_parent = c.parent
            dest_name = c.name
            break

    if dest_parent is None:
        # None exists → use the first candidate
        if not candidates:
            err("No destination paths known for this operating system.")
            return
        dest_parent = candidates[0].parent
        dest_name = candidates[0].name

    dest_path = dest_parent / dest_name

    log(f"Archive     : {archive.name}")
    log(f"Destination : {dest_path}")

    if helium_running():
        warn("Helium appears to be running – please quit it first!")
        if not ask_confirm("Import anyway?", default_yes=False):
            log("Aborted.")
            return

    # Back up the current profile, if present
    if dest_path.exists():
        backup_old = dest_path.with_name(
            dest_name + ".bak_" + datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        )
        warn(f"Existing profile will be backed up to: {backup_old}")
        if not ask_confirm(
            "Rename the current profile and then overwrite?", default_yes=True
        ):
            log("Aborted.")
            return
        dest_path.rename(backup_old)

    dest_parent.mkdir(parents=True, exist_ok=True)

    log("Extracting archive …")
    with tarfile.open(archive, "r:gz") as tar:
        members = tar.getmembers()
        # Safety check: no absolute paths or ".." in the archive
        for member in members:
            member_path = Path(member.name)
            if member_path.is_absolute() or ".." in member_path.parts:
                err(f"Unsafe path in archive: {member.name} – aborting.")
                return
        try:
            tar.extractall(path=dest_parent, filter="data")
        except TypeError:  # Python < 3.12
            tar.extractall(path=dest_parent)

    # The archive's top-level dir carries the source machine's profile name;
    # rename it if this machine expects a different one.
    roots = {Path(m.name).parts[0] for m in members}
    if len(roots) == 1:
        extracted = dest_parent / roots.pop()
        if extracted != dest_path and extracted.is_dir():
            extracted.rename(dest_path)

    sep()
    ok(f"Profile successfully restored to: {dest_path}")
    ok("Helium can now be started.")


# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------


def select_mode() -> str:
    print()
    print("What would you like to do?")
    print("  [1] Export  – back up the current Helium profile")
    print("  [2] Import  – restore a saved profile")
    while True:
        raw = input("  Choice (1/2): ").strip()
        if raw == "1":
            return "export"
        if raw == "2":
            return "import"
        warn("Please enter 1 or 2.")


def main() -> None:
    # In PyInstaller frozen mode, __file__ points to the temp directory.
    # sys.executable is then the actual binary; in normal mode we use __file__.
    if getattr(sys, "frozen", False):
        script_dir = Path(sys.executable).parent.resolve()
    else:
        script_dir = Path(__file__).parent.resolve()

    sep()
    print(_c("1;36", "  Helium Browser Backup & Restore"))
    print(_c("90", f"  Script directory: {script_dir}"))
    sep()
    print()

    # 1. Operating system
    os_name = select_os()
    print()

    # 2. Mode
    mode = select_mode()
    print()

    if mode == "export":
        # Look for the source path
        src = find_helium_src(os_name)
        if src is None:
            err("Helium profile directory not found.")
            err("Checked paths:")
            for p in CANDIDATE_PATHS.get(os_name, []):
                err(f"  - {p}")
            err("Tip: set the HELIUM_SRC=/path/to/profile environment variable.")
            # Manual entry
            manual = input("Enter path manually (or press Enter to cancel): ").strip()
            if not manual:
                sys.exit(1)
            src = Path(manual)
            if not src.is_dir():
                err(f"Directory does not exist: {src}")
                sys.exit(1)
        do_export(src, script_dir)

    else:  # import
        do_import(os_name, script_dir)

    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        log("Aborted.")
        sys.exit(0)
