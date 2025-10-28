#!/usr/bin/env python3
"""Entry point for the Python basic project starter.

This script demonstrates:
* Structured logging
* Argument parsing
* A predictable `main()` entry point
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path


def configure_logging(level: int = logging.INFO) -> None:
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Example CLI for the Automatic Dev python-basic template"
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("data/input.csv"),
        help="Path to input dataset",
    )
    return parser.parse_args()


def main() -> None:
    configure_logging()
    args = parse_args()
    logging.info("Starting script run")
    logging.info("Input path: %s", args.input.resolve())
    logging.info(
        "Replace this message with your project logic. "
        "Keep business logic inside src/ and cover it with tests/."
    )


if __name__ == "__main__":
    main()
