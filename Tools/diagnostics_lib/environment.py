"""Low-cardinality host metadata used only for capture compatibility."""

from __future__ import annotations

import platform
import subprocess
from typing import Any


def capture_environment() -> dict[str, Any]:
    """Describe the machine class without volatile utilization details."""

    model_result = subprocess.run(
        ["/usr/sbin/sysctl", "-n", "hw.model"],
        capture_output=True,
        check=False,
        text=True,
    )
    model = model_result.stdout.strip() if model_result.returncode == 0 else "unknown"
    return {
        "schemaVersion": 1,
        "machineArchitecture": platform.machine(),
        "machineModel": model,
        "operatingSystem": platform.system(),
        "operatingSystemVersion": platform.mac_ver()[0],
    }
