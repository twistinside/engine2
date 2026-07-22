"""Command-line vocabulary for repeatable Engine2 diagnostics."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .capture import CaptureError, CaptureRequest, capture
from .logs import LogCapturePolicy
from .traces import TraceCapturePolicy
from .summary import summarize_capture
from .comparison import compare_captures


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
    capture_parser.add_argument(
        "--logs",
        choices=[policy.value for policy in LogCapturePolicy],
        default=LogCapturePolicy.BEST_EFFORT.value,
        help="required, best-effort, or skip unified-log archival",
    )
    capture_parser.add_argument(
        "--trace",
        choices=[policy.value for policy in TraceCapturePolicy],
        default=TraceCapturePolicy.BEST_EFFORT.value,
        help="required, best-effort, or skip Instruments recording",
    )
    summarize_parser = subparsers.add_parser("summarize", help="generate JSON and Markdown summaries")
    summarize_parser.add_argument("--capture", required=True, type=Path)
    compare_parser = subparsers.add_parser("compare", help="compare compatible capture summaries")
    compare_parser.add_argument("--baseline", required=True, type=Path)
    compare_parser.add_argument("--candidate", required=True, type=Path)
    compare_parser.add_argument("--budgets", type=Path)
    loop_parser = subparsers.add_parser(
        "loop",
        help="capture two repeatability runs and enforce reviewed budgets",
    )
    loop_parser.add_argument("--app", required=True, type=Path)
    loop_parser.add_argument("--output", required=True, type=Path)
    loop_parser.add_argument("--budgets", required=True, type=Path)
    loop_parser.add_argument("--scenario", default="baseline-six-ball")
    loop_parser.add_argument("--seed", default=42, type=_unsigned_integer)
    loop_parser.add_argument("--warm-up-nanoseconds", default=2_000_000_000, type=_unsigned_integer)
    loop_parser.add_argument(
        "--measurement-nanoseconds", default=15_000_000_000, type=_positive_integer
    )
    loop_parser.add_argument(
        "--logs",
        choices=[policy.value for policy in LogCapturePolicy],
        default=LogCapturePolicy.SKIP.value,
    )
    loop_parser.add_argument(
        "--trace",
        choices=[policy.value for policy in TraceCapturePolicy],
        default=TraceCapturePolicy.SKIP.value,
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
                    log_policy=LogCapturePolicy(args.logs),
                    trace_policy=TraceCapturePolicy(args.trace),
                )
            )
            return 0
        if args.command == "summarize":
            summarize_capture(args.capture.expanduser().resolve())
            return 0
        if args.command == "compare":
            result = compare_captures(
                args.baseline.expanduser().resolve(),
                args.candidate.expanduser().resolve(),
                args.budgets.expanduser().resolve() if args.budgets else None,
            )
            return int(result["exitCode"])
        if args.command == "loop":
            output = args.output.expanduser().resolve()
            if output.exists():
                raise CaptureError(f"output already exists: {output}")
            request_values = {
                "app": args.app,
                "scenario": args.scenario,
                "seed": args.seed,
                "warm_up_nanoseconds": args.warm_up_nanoseconds,
                "measurement_nanoseconds": args.measurement_nanoseconds,
                "log_policy": LogCapturePolicy(args.logs),
                "trace_policy": TraceCapturePolicy(args.trace),
            }
            baseline = output / "baseline"
            candidate = output / "candidate"
            capture(CaptureRequest(output=baseline, **request_values))
            capture(CaptureRequest(output=candidate, **request_values))
            result = compare_captures(
                baseline,
                candidate,
                args.budgets.expanduser().resolve(),
            )
            return int(result["exitCode"])
    except (CaptureError, FileNotFoundError, ValueError, json.JSONDecodeError) as error:
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
