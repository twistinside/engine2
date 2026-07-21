"""Command-line vocabulary for repeatable Engine2 diagnostics."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from .capture import CaptureError, CaptureRequest, capture


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="Tools/diagnostics")
    subparsers = parser.add_subparsers(dest="command", required=True)
    capture_parser = subparsers.add_parser("capture", help="run and validate one built app")
    capture_parser.add_argument("--app", required=True, type=Path)
    capture_parser.add_argument("--output", required=True, type=Path)
    capture_parser.add_argument("--scenario", default="baseline-six-ball")
    capture_parser.add_argument("--seed", default=42, type=_unsigned_integer)
    capture_parser.add_argument("--warm-up-nanoseconds", default=2_000_000_000, type=_unsigned_integer)
    capture_parser.add_argument(
        "--measurement-nanoseconds", default=15_000_000_000, type=_positive_integer
    )
    return parser


def main(arguments: list[str] | None = None) -> int:
    args = build_parser().parse_args(arguments)
    try:
        if args.command == "capture":
            capture(
                CaptureRequest(
                    app=args.app,
                    output=args.output,
                    scenario=args.scenario,
                    seed=args.seed,
                    warm_up_nanoseconds=args.warm_up_nanoseconds,
                    measurement_nanoseconds=args.measurement_nanoseconds,
                )
            )
            return 0
    except CaptureError as error:
        print(f"diagnostics: {error}", file=sys.stderr)
        return 1
    return 1


def _unsigned_integer(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be an unsigned integer")
    return parsed


def _positive_integer(value: str) -> int:
    parsed = _unsigned_integer(value)
    if parsed == 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed
