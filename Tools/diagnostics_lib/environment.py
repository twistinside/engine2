"""Low-cardinality host metadata used only for capture compatibility."""

from __future__ import annotations

import platform
from pathlib import Path
import plistlib
import subprocess
from typing import Any


def capture_environment(app: Path | None = None) -> dict[str, Any]:
    """Describe source, toolchain, app, and machine provenance without utilization noise."""

    repository_root = Path(__file__).resolve().parents[2]
    git_status = _command_output(["/usr/bin/git", "status", "--porcelain"], repository_root)
    app_metadata = _app_metadata(app)
    return {
        "schemaVersion": 1,
        "machineArchitecture": platform.machine(),
        "machineModel": _command_output(["/usr/sbin/sysctl", "-n", "hw.model"]) or "unknown",
        "processor": _command_output(["/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"]),
        "physicalMemoryBytes": _integer_output(["/usr/sbin/sysctl", "-n", "hw.memsize"]),
        "operatingSystem": platform.system(),
        "operatingSystemVersion": platform.mac_ver()[0],
        "gitRevision": _command_output(["/usr/bin/git", "rev-parse", "HEAD"], repository_root),
        "gitDirty": bool(git_status),
        "xcodeVersion": _command_output(["/usr/bin/xcodebuild", "-version"]),
        "swiftCompilerVersion": _command_output(["/usr/bin/xcrun", "swiftc", "--version"]),
        **app_metadata,
    }


def _app_metadata(app: Path | None) -> dict[str, Any]:
    if app is None:
        return {}
    resolved = app.expanduser().resolve()
    bundle = resolved if resolved.suffix == ".app" else None
    if bundle is None:
        return {}
    info_path = bundle / "Contents" / "Info.plist"
    if not info_path.is_file():
        return {}
    with info_path.open("rb") as info_file:
        info = plistlib.load(info_file)
    return {
        "appBundleIdentifier": info.get("CFBundleIdentifier"),
        "appVersion": info.get("CFBundleShortVersionString"),
        "appBuildVersion": info.get("CFBundleVersion"),
    }


def _command_output(command: list[str], cwd: Path | None = None) -> str | None:
    result = subprocess.run(command, cwd=cwd, capture_output=True, check=False, text=True)
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def _integer_output(command: list[str]) -> int | None:
    value = _command_output(command)
    try:
        return int(value) if value is not None else None
    except ValueError:
        return None
